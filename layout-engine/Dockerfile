FROM docker.io/library/python:3.13

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

ENV CONFIG_PATH "/app/config/2-column.yaml"

CMD ["flask", "run", "--debug", "--host=0.0.0.0", "--extra-files=templates/index.html:templates/common.html:config/2-column.yaml"]