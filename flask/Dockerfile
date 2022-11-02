FROM --platform=linux/amd64 python:3.7-alpine

WORKDIR /app

RUN pip3 install flask

COPY . .

CMD [ "python3", "app.py"]