FROM python:3.7

# should be run from repository base
# docker build -f docker/Dockerfile -t vanessa/job-maker .

RUN apt-get update && \
    apt-get install -y tree && \
    mkdir -p /code /data

ADD . /code

RUN chmod u+x /code/docker/entrypoint.sh
WORKDIR /code
ENTRYPOINT ["/bin/bash", "/code/docker/entrypoint.sh"]
