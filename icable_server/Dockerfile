FROM python:3
WORKDIR /usr/src/app
COPY . .
RUN pip install --no-cache-dir -r ./requirement.txt
VOLUME [ "/root/.local/share/icable" ]
CMD ["python3","icableServer.py"]