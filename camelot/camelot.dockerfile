FROM ubuntu:18.04 AS python_base
RUN apt-get update && apt-get install --no-install-recommends -y \
    python3.8 \
    python3.8-dev \
    python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN rm /usr/bin/python3 && \
    ln -s /usr/bin/python3.8 /usr/bin/python && \
    ln -s /usr/bin/python3.8 /usr/bin/python3 && \
    python3 -m pip install --no-cache-dir --upgrade pip

FROM python_base AS app_base
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jerusalem

RUN apt-get update && apt-get install --no-install-recommends -y \
     ghostscript \
     python3-tk \
     libc-dev \
     build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir \
     cython \
     numpy \
     opencv-python \
     camelot-py[cv] \
     matplotlib

FROM app_base as app
CMD ["/bin/bash"]
