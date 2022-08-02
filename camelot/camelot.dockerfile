FROM ubuntu:18.04 AS python_base
RUN apt-get update && apt-get install -y \
    python3.8 \
    python3.8-dev \
    python3-pip
RUN rm /usr/bin/python3
RUN ln -s /usr/bin/python3.8 /usr/bin/python
RUN ln -s /usr/bin/python3.8 /usr/bin/python3
RUN python3 -m pip install --upgrade pip

FROM python_base AS app_base
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jerusalem

RUN apt-get update && apt-get install -y \
    ghostscript \
    python3-tk \
    libc-dev \
    build-essential
RUN python3 -m pip install \
    cython \
# RUN python3 -m pip install \
    numpy \
    opencv-python
RUN python3 -m pip install \
    camelot-py[cv] \
    matplotlib

FROM app_base as app
CMD ["/bin/bash"]
