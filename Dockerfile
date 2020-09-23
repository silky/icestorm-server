FROM ubuntu:16.04



# yosys
RUN apt-get update && apt-get install -y build-essential clang bison flex \
	libreadline-dev gawk tcl-dev libffi-dev git \
	graphviz xdot pkg-config python3 libboost-system-dev \
	libboost-python-dev libboost-filesystem-dev zlib1g-dev nodejs npm

RUN git clone https://github.com/YosysHQ/yosys.git

WORKDIR yosys

RUN make
RUN make install

# icestorm - http://www.clifford.at/icestorm/
# TODO: Pin to commit - d12308775684cf43ab923227235b4ad43060015e
RUN apt-get update && apt-get -y install build-essential clang bison flex libreadline-dev \
                     gawk tcl-dev libffi-dev git mercurial \
                     xdot pkg-config python python3 libftdi-dev \
                     python3-dev libboost-all-dev cmake libeigen3-dev
WORKDIR /
RUN git clone https://github.com/cliffordwolf/icestorm.git icestorm
WORKDIR icestorm
RUN make -j$(nproc)
RUN make install

# nextpnr  - https://github.com/YosysHQ/nextpnr
# TODO: Pin to commit - be607c10a860c1043dc7554463a8e788759809d8
WORKDIR /
RUN git clone https://github.com/YosysHQ/nextpnr.git
WORKDIR nextpnr
RUN echo "ENABLE_LANGUAGE(C)">foo.txt
RUN cat CMakeLists.txt>>foo.txt
RUN mv foo.txt CMakeLists.txt
RUN cmake . -DARCH=ice40 -DBUILD_GUI=OFF
RUN make
RUN make install


# Node.js for the web server
RUN apt-get update && apt-get install -y curl

# Install NPM dependencies
WORKDIR /app
COPY ./server/package*.json ./

# Get the right version of node
RUN npm install
RUN npm install -g n
RUN n 12.18.3

# Copy Node.js application source
COPY ./server/app.js .
COPY ./server/synthesis/ ./synthesis

# Start Node.js app
CMD ["node", "app.js"]
