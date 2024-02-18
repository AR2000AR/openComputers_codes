#!/bin/python3

if (__name__ != '__main__'):
    exit()

import socket
import threading
from cgi import parse_header, parse_multipart
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, HTTPServer
import ipaddress
from pathlib import Path
from signal import SIGINT, SIGTERM, signal
from string import Template
from urllib.parse import parse_qs
import pathlib

import models.database
import models.firewall
import models.network
import models.user
import models.web
from icable.firewall import *
from icable.packet import *
from icable.protocol import *

dataPath = pathlib.Path(pathlib.Path.home(), '.local', 'share', 'icable')
dataPath.mkdir(parents=True, exist_ok=True)

db = models.database.DatabaseHandler(pathlib.Path(dataPath, 'icable.db'))
users = models.user.Users(db)
webSessions = models.web.WebSessions(db)
networks = models.network.Networks(db)
firewalls = models.firewall.Firewalls(db)

run = threading.Event()
run.set()


def stop(signal: int, stackFrame):
    print("Graceful stop step 1")
    run.clear()
    print("Graceful stop step 2")
    for node in clientList:
        node.join()


signal(SIGTERM, stop)
signal(SIGINT, stop)


def recievePacket(sock: socket.socket):
    data = b''
    while len(data) < 8:
        data = sock.recv(8-len(data))
        if (data == b''):
            raise ConnectionResetError()
    pklen = IcablePacket.getLenFromHeaderData(data)
    while len(data) < 8 + pklen:
        read = sock.recv(pklen - (len(data)-8))
        if (read == b''):
            raise ConnectionResetError()
        data += read
    return IcablePacket.unpack(data)


class Node(threading.Thread):

    def __init__(self, socket: socket.socket, *args, **keyargs):
        self.clientID = -1
        self.address = (0, 0)
        self.socket = socket
        self._pendingUser = False
        super(Node, self).__init__(*args, **keyargs)

    def run(self):
        try:
            while run.is_set():
                packet = recievePacket(self.socket)
                match packet.kind:
                    case ICABLE_PACKET_KIND.CLIENT_AUTH:
                        self.handler_client_auth(
                            IcableClientAuth.unpack(packet.payload))
                    case ICABLE_PACKET_KIND.CLIENT_AUTH_REQUEST:
                        self.handler_client_auth_request(
                            IcableClientAuthRequest.unpack(packet.payload))
                    case _ if (not self.user):
                        self.error(SERVER_ERROR_KIND.NOT_AUTH,
                                   'Client is not authenticated')
                    case ICABLE_PACKET_KIND.CLIENT_NETCONF:
                        self.handler_netconf(
                            IcableNetconf.unpack(packet.payload))
                    case ICABLE_PACKET_KIND.CLIENT_DATA:
                        self.handler_data(packet)
                    case _:
                        self.error(SERVER_ERROR_KIND.UNKNOWN_MSG)
        except ConnectionResetError:
            print(f'Client {self.socket.getsockname()} disconnected')
        finally:
            clientList.remove(self)
            self.socket.close()

    def error(self, kind: SERVER_ERROR_KIND, msg=None):
        breakpoint()
        self.socket.send(IcablePacket(
            ICABLE_PACKET_KIND.SERVER_ERROR, IcableServerError(kind, msg).pack()).pack())

    def handler_client_auth(self, auth: IcableClientAuth):
        print(f'Authenticating {auth.uname}')
        srvAuth = IcableServerAuth(False)
        user = users.getUserFromLogin(auth.uname)
        if (not user):
            icablePayload = IcablePacket(
                ICABLE_PACKET_KIND.SERVER_AUTH, srvAuth.pack())
            self.socket.send(icablePayload.pack())
            self._pendingUser = False
            return

        assert (isinstance(user, models.user.User))
        match self._pendingUser:
            case False:  # normal auth
                srvAuth.sucess = user.verify(auth.password)
            # secure auth
            case pendingUser if isinstance(pendingUser, models.user.User):
                if (pendingUser.login == user.login):
                    srvAuth.sucess = pendingUser.secureVerify(auth.password)
                self._pendingUser = False

        icablePayload = IcablePacket(
            ICABLE_PACKET_KIND.SERVER_AUTH, srvAuth.pack())
        self.socket.send(icablePayload.pack())
        if (srvAuth.sucess):
            self.user = user

    def handler_client_auth_request(self, info: IcableClientAuthRequest):
        user = users.getUserFromLogin(info.username)
        if (user):
            self._pendingUser = user
            serverAuthRequest = IcableServerAuthRequest(
                user.salt, user.authenticationSalt)
            icablePacket = IcablePacket(
                ICABLE_PACKET_KIND.SERVER_AUTH_REQUEST, serverAuthRequest.pack())
            self.socket.send(icablePacket.pack())
        else:
            self.socket.send(IcablePacket(
                ICABLE_PACKET_KIND.SERVER_AUTH(IcableServerAuth(False))))

    def handler_netconf(self, netconf: IcableNetconf):
        match netconf.kind:
            case CLIENT_NETCONF_KIND.AUTO_IPv4 if netconf.ipv4:
                allowed = self.canUserConnectToNetwork(netconf)
                if (not allowed):
                    self.error(SERVER_ERROR_KIND.NETCONF_ERROR,
                               'Network not allowed')
                else:
                    self.error(SERVER_ERROR_KIND.UNKNOWN_MSG,
                               'Automatic address attribution on a network is not implemented')
            case CLIENT_NETCONF_KIND.AUTO_IPv4:
                self.error(SERVER_ERROR_KIND.UNKNOWN_MSG,
                           'Automatic address attribution is not implemented')
            case CLIENT_NETCONF_KIND.MANUAL_IPv4 if netconf.ipv4 not in [client.address[0] for client in clientList]:
                allowed = self.canUserConnectToNetwork(netconf)
                if (allowed == True):
                    netconf.kind = SERVER_NETCONF_KIND.IPv4
                    icablePayload = IcablePacket(
                        ICABLE_PACKET_KIND.SERVER_NETCONF, netconf.pack())
                    self.address = (netconf.ipv4, netconf.mask)
                    print(f"Client address : {self.address}")
                    self.socket.send(icablePayload.pack())
                else:
                    self.error(SERVER_ERROR_KIND.NETCONF_ERROR,
                               'Network not allowed')
            case CLIENT_NETCONF_KIND.MANUAL_IPv4:
                if (netconf.ipv4 in [client.address[0] for client in clientList]):
                    self.error(SERVER_ERROR_KIND.NETCONF_ERROR,
                               'Address already in use')
            case _:
                self.error(SERVER_ERROR_KIND.NETCONF_ERROR,
                           "Unsuported netconf kind")

    def canUserConnectToNetwork(self, netconf):
        assert (isinstance(self.user, models.user.User))
        allowedNetworks: list[models.Network] = self.user.networks
        for network in allowedNetworks:
            if (network.network == netconf.interface.network):
                return True
        return False

    def handler_data(self, packet: IcablePacket):
        assert (isinstance(self.user, models.user.User))
        ipMsg = IPv4Datagram.unpack(packet.payload)
        if (ipaddress.ip_address(ipMsg.src) != self.address[0]):
            self.error(SERVER_ERROR_KIND.NETCONF_MISSMATCH)
            return
        try:
            client = [client for client in clientList if client.address[0] == ipaddress.ip_address(ipMsg.dst)
                      and client.user.subnetid == self.user.subnetid][0]
            if (firewalls[self.user.subnetid].getAction(ipMsg) == FIREWALL_ACTION.ALLOW):
                client.socket.send(IcablePacket(
                    ICABLE_PACKET_KIND.SERVER_DATA, ipMsg.pack()).pack())
        except IndexError:
            # No destination found
            pass


clientList = list[Node]()


class WebInterface(BaseHTTPRequestHandler):

    @staticmethod
    # @cache
    def get_template(templateName: str):
        with open(Path(Path(__file__).parent, 'http_ressources', templateName)) as f:
            return Template(f.read())

    @staticmethod
    # @cache
    def get_file(filename: str):
        with open(Path(Path(__file__).parent, 'http_ressources', filename)) as f:
            return f.read()

    def parse_POST(self) -> dict[str, list[str]]:
        ctype, pdict = parse_header(self.headers['content-type'])
        if ctype == 'multipart/form-data':
            postvars = parse_multipart(self.rfile, pdict)
        elif ctype == 'application/x-www-form-urlencoded':
            length = int(self.headers['content-length'])
            postvars = parse_qs(
                self.rfile.read(length),
                keep_blank_values=True)
        else:
            postvars = dict[bytes, list[bytes]]()
        postvars = {k.decode(): [vv.decode() for vv in v]
                    for k, v in postvars.items()}
        return postvars

    def checkLoggedIn(self):
        if (not 'sid' in self.cookies):
            try:
                del self.user
            except AttributeError:
                pass
            return False
        user = webSessions.getSession(int(self.cookies['sid'].value))
        if (not user):
            try:
                del self.user
            except AttributeError:
                pass
            return False
        self.user = user
        return True

    def redirect(self, location: str, endHeader=True, code=302):
        self.send_response(code)
        self.send_header('Location', location)
        if (endHeader == True):
            self.end_headers()

    def do_GET(self):
        self.cookies = SimpleCookie(self.headers.get('Cookie'))
        routes = {
            "/": self.get_index,
            "/index.html": self.get_index,
            "/clients": self.get_clients,
            "/network": self.get_networks,
            "/signup": self.get_signup,
            "/user": self.get_user,
        }

        if (self.path[0:5] == '/css/'):
            self.serveCSS()
        else:
            if (not self.checkLoggedIn() and not (self.path in {'/', '/index.html', '/signup'})):
                self.redirect('/')
                return
            if self.path in routes:
                routes[self.path]()
            else:
                self.send_error(404, *self.responses[404])

    def do_POST(self):
        self.cookies = SimpleCookie(self.headers.get('Cookie'))
        self.post = self.parse_POST()
        routes = {
            '/login': self.post_login,
            '/logout': self.post_logout,
            '/network': self.post_network,
            '/signup': self.post_signup,
            '/firewall': self.post_firewall,
            '/user': self.post_user,
        }
        if (not self.checkLoggedIn() and not (self.path in {'/login', '/logout', '/signup'})):
            self.send_error(401, 'Not authenticated')
        if self.path in routes:
            routes[self.path]()
        else:
            self.send_error(404, *self.responses[404])

    def makeLoginDiv(self, base_html):
        loggedInTmpl = Template(self.get_file('loggedIn.html'))
        return Template(base_html).safe_substitute(login=loggedInTmpl.safe_substitute(username=self.user.login))

    def serveCSS(self):
        try:
            fileData = bytes(self.get_file(self.path[1:]), 'utf-8')
            self.send_response(200)
            self.send_header("Content-type", "text/css")
            self.end_headers()
            self.wfile.write(fileData)
        except FileNotFoundError:
            self.send_error(404)

    def get_index(self):
        if (self.checkLoggedIn()):
            self.redirect('/clients')
            return
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        html = self.get_file('index.html')
        self.wfile.write(bytes(html, 'utf-8'))

    def get_clients(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

        tableContent = ''
        for client in clientList:
            tableContent += f"""<tr>
                <td>{ipaddress.ip_address(client.socket.getpeername()[0]).compressed+':'+str(client.socket.getpeername()[1])}</td>
                <td>{ipaddress.ip_address(client.address[0]).compressed+'/'+str(client.address[1])}</td>
                <td>{client.user.login}</td>
                </tr>
            """

        html = self.get_template('clients.html').safe_substitute(
            clientList=tableContent)
        html = self.makeLoginDiv(html)
        self.wfile.write(bytes(html, 'utf-8'))

    def post_login(self):
        self.redirect('/', False)
        user = users.getUserFromLogin(self.post['username'][0])
        if (user and user.verify(self.post['password'][0])):
            self.cookies['sid'] = str(webSessions.createSession(user))
        self.send_header('Set-Cookie', self.cookies.output(header=''))
        self.end_headers()

    def post_logout(self):
        self.redirect('/', False)
        if ('sid' in self.cookies):
            morsel = self.cookies['sid']
            sid = int(morsel.value)
            webSessions.deleteSession(sid)
            morsel['expires'] = 'Thu, 01 Jan 1970 00:00:00 GMT'
        self.send_header('Set-Cookie', self.cookies.output(header=''))
        self.end_headers()

    def get_networks(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

        mapping = {}

        # region network
        mapping['networkList'] = ''
        user_networks = self.user.networks
        user_networks.sort()
        for network in user_networks:
            dl_button = ""
            if (self.user.get_network_permission(network) == 1 or models.user.SubnetworkPermission.OWNER in self.user.subnetwork_permission):
                dl_button = f"""<form action='/network' method='post'>
                        <input class='ip-cell' type='submit' value='Delete'>
                        <input class='ip-cell' type='hidden' name='cmd' value='delete'>
                        <input type='hidden' name='netid' value='{network.id}'>
                    </form>"""

            mapping['networkList'] += f"""<tr>
                <td>{network.network.network_address.compressed}</td>
                <td>{network.network.netmask.compressed}</td>
                <td>{dl_button}</dt>
            </tr>
            """
        # endregion

        # region firewall
        mapping['firewallDefault'] = firewalls[self.user.subnetid].action.name
        FIREWALL_ALLOWED = models.user.SubnetworkPermission.FIREWALL | models.user.SubnetworkPermission.OWNER

        mapping['firewallRuleList'] = ""
        for rule in firewalls[self.user.subnetid].rules:
            dl_button = ""
            if (FIREWALL_ALLOWED in self.user.subnetwork_permission):
                dl_button = f"<input type='submit' value='Delete'>"
            mapping['firewallRuleList'] += f"""<tr>
                <form action='/firewall' method='post'>
                    <td class='cidr-cell'>{rule.src.compressed}</td>
                    <input type='hidden' name='src' value='{rule.src.compressed}'>
                    <td class='cidr-cell'>{rule.dst.compressed}</td>
                    <input type='hidden' name='dst' value='{rule.dst.compressed}'>
                    <td>{rule.action.name}</td>
                    <input type='hidden' name='action' value='{rule.action.name}'>
                    <td>{dl_button}</td>
                    <input type='hidden' name='cmd' value='delete'>
                </form>
            </tr>
            """

        mapping['firewallRuleForm'] = """<tr>
                    <form id="firewallForm" action="/firewall" method="post">
                        <td><input type="text" placeholder="Source" name="src" required
                                pattern="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/[1-3]?[0-9]$">
                        </td>
                        <td><input type="text" placeholder="Destination" name="dst" required
                                pattern="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/[1-3]?[0-9]$">
                        </td>
                        <td><select value="ALLOW" name="action">
                                <option value="1">ALLOW</option>
                                <!--<option value="2">REJECT</option>-->
                                <option value="3">DROP</option>
                            </select></td>
                        <input type="hidden" name="cmd" value="new">
                        <td><input type="submit" value="Create"></td>
                    </form>
                </tr>""" if FIREWALL_ALLOWED in self.user.subnetwork_permission else ""

        # endregion

        # region pool

        mapping['poolid'] = self.user.subnetid
        mapping['poolusers'] = ''
        for user in users.get_users_in_subnet(self.user.subnetid):
            role = "Guest"
            if (models.user.SubnetworkPermission.FIREWALL in user.subnetwork_permission):
                role = "Firewall"
            if (models.user.SubnetworkPermission.OWNER in user.subnetwork_permission):
                role = "Owner"
            mapping['poolusers'] += f"""<tr>
                <td>{user.login}</td>
                <td>{role}</td>
            </tr>
            """

        # endregion

        html = self.get_template('networks.html').safe_substitute(mapping)
        html = self.makeLoginDiv(html)
        self.wfile.write(bytes(html, 'utf-8'))

    def post_network(self):
        self.redirect('/network', code=303)
        if (self.post['cmd'][0] == 'new'):
            network = ipaddress.ip_network(
                (self.post['network'][0], self.post['mask'][0]))
            assert (isinstance(network, ipaddress.IPv4Network))
            network = networks.createNetwork(self.user.subnetid, network)
            self.user.addNetwork(network, 1)
        elif (self.post['cmd'][0] == 'delete'):
            network = networks.getNetworkById(int(self.post['netid'][0]))
            if (network):
                networks.deleteNetwork(network)

    def get_signup(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

        html = self.get_file('signup.html')
        self.wfile.write(bytes(html, 'utf-8'))

    def post_signup(self):
        if (not users.getUserFromLogin(self.post['username'][0])):
            if (self.post['password'][0] == self.post['passwordConfirmation'][0]):
                user = users.createUser(
                    self.post['username'][0], self.post['password'][0])
                if (user):
                    self.cookies['sid'] = str(webSessions.createSession(user))
                    self.send_response(301)
                    self.send_header("Location", "/")
                    self.send_header(
                        'Set-Cookie', self.cookies.output(header=''))
                    self.end_headers()
                    return

        self.redirect('/signup', 303)

    def post_firewall(self):
        if (self.post['cmd'][0] == 'new'):
            firewall = firewalls[self.user.subnetid]
            rule = FirewallRule()
            rule.src = self.post['src'][0]
            rule.dst = self.post['dst'][0]
            rule.action = FIREWALL_ACTION(int(self.post['action'][0]))
            firewall.appendRule(rule)
            firewalls[self.user.subnetid] = firewall  # save the firewall
        elif (self.post['cmd'][0] == 'delete'):
            firewall = firewalls[self.user.subnetid]
            rule = FirewallRule()
            rule.src = self.post['src'][0]
            rule.dst = self.post['dst'][0]
            rule.action = FIREWALL_ACTION[self.post['action'][0]]
            for frule in firewall.rules:
                if frule == rule:
                    firewall.removeRule(frule)
                    break
            firewalls[self.user.subnetid] = firewall  # save the firewall
        self.redirect('/network', code=303)

    def get_user(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

        html = self.get_file('user.html')
        html = self.makeLoginDiv(html)
        self.wfile.write(bytes(html, 'utf-8'))

    def post_user(self):
        match self.post['cmd'][0]:
            case 'password' if not self.user.verify(self.post['password'][0]):
                self.redirect(self.path, code=303)
            case 'password' if self.post['newPassword'][0] != self.post['newPassword2'][0]:
                self.redirect(self.path, code=303)
            case 'password':
                self.user.password = self.post['newPassword'][0]
                self.redirect(self.path, code=303)
            case 'delete':
                users.deleteUser(self.user)
                self.post_logout
            case _:
                self.redirect(self.path, code=303)


# webserver = HTTPServer(('127.0.0.1',8080),WebInterface)
webserver = HTTPServer(('0.0.0.0', 8080), WebInterface)
webserverThread = threading.Thread(
    target=webserver.serve_forever, name="Web interface")
webserverThread.start()
print(f'Web server on {webserver.socket.getsockname()}')

s = socket.create_server(("127.0.0.1", 4222), reuse_port=True)
s.listen()
print(f'icable tcp socket listening on {s.getsockname()}')
while run.is_set():
    clientSocket, clientIP = s.accept()
    print(f'Incomming connexion from {clientIP}')
    clientSocket.setblocking(True)
    clientThread = Node(socket=clientSocket, name=f'Client Thread {clientIP}')
    clientList.append(clientThread)
    clientThread.start()
