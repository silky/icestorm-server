ARG BASE_IMAGE=ubuntu:20.04
FROM $BASE_IMAGE
ARG DEBIAN_FRONTEND=noninteractive

# enable apt-cacher
RUN cat >/dev/tcp/10.0.10.62/3142 </dev/null\
    && sed -e 's/http:\/\//http:\/\/10.0.10.62:3142\//g' -i /etc/apt/sources.list

# IceStorm prerequiresites
RUN apt-get update && apt-get install -y \
        build-essential clang bison flex libreadline-dev \
        gawk tcl-dev libffi-dev git mercurial graphviz   \
        xdot pkg-config python2.7 python3 libftdi-dev \
        qt5-default python3-dev libboost-all-dev cmake

COPY ./repositories /

# IceStorm
WORKDIR /icestorm
RUN make -j$(nproc)
RUN make install

# Arachne-PNR
WORKDIR /arachne-pnr
RUN make -j$(nproc)
RUN make install

# Yosys
WORKDIR /yosys
RUN make -j$(nproc)
RUN make install

# Node.js for the web server
RUN apt-get update && apt-get install -y nodejs npm

# Install NPM dependencies
WORKDIR /app
COPY ./server/package*.json ./
RUN npm install

# Copy Node.js application source
COPY ./server/app.js .
COPY ./server/synthesis/ ./synthesis

# Start Node.js app
CMD ["node", "app.js"]
