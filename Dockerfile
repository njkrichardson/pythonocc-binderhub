FROM jupyter/scipy-notebook:7a0c7325e470

MAINTAINER Thomas Paviot <tpaviot@gmail.com>

USER root

ENV DEBIAN_FRONTEND=noninteractive

##############
# apt update #
##############
RUN apt-get update

RUN apt-get install -y wget git build-essential libgl1-mesa-dev libfreetype6-dev libglu1-mesa-dev libzmq3-dev libsqlite3-dev libicu-dev python3-dev libgl2ps-dev libfreeimage-dev libtbb-dev ninja-build bison autotools-dev automake libpcre3 libpcre3-dev tcl8.5 tcl8.5-dev tk8.5 tk8.5-dev libxmu-dev libxi-dev libopenblas-dev libboost-all-dev swig libxml2-dev

RUN dpkg-reconfigure --frontend noninteractive tzdata

############################
# pip third part libraries #
############################
RUN pip install svgwrite
RUN pip install vtk
RUN pip install cmake==3.15.3

################################################################
# OCCT 7.4.0p1                                                 #
# Download the source code archive package from OCE repository #
################################################################
WORKDIR /opt/build
RUN wget https://github.com/tpaviot/oce/releases/download/official-upstream-packages/opencascade-7.4.0p1.snapshot.tar.gz
RUN tar -zxvf opencascade-7.4.0p1.snapshot.tar.gz >> extracted_occt740p1_files.txt
RUN mkdir occt-V7_4_0p1/build
WORKDIR /opt/build/occt-V7_4_0p1/build

RUN ls /usr/include
RUN cmake -G Ninja \
 -DUSE_TBB:BOOL=ON \
 -DUSE_FREEIMAGE:BOOL=ON \
 -DBUILD_RELEASE_DISABLE_EXCEPTIONS:BOOL=OFF \
 -DINSTALL_DIR=/opt/build/occt740p1 \
 ..

RUN ninja install

RUN echo "/opt/build/occt740p1/lib" >> /etc/ld.so.conf.d/occt.conf
RUN ldconfig

RUN ls /opt/build/occt740p1
RUN ls /opt/build/occt740p1/lib

ENV CASROOT=/opt/build/occt740p1

#############
# pythonocc #
#############
WORKDIR /opt/build
RUN git clone https://github.com/tpaviot/pythonocc-core
WORKDIR /opt/build/pythonocc-core
RUN git checkout review/x3d-export
WORKDIR /opt/build/pythonocc-core/build

RUN cmake -G Ninja \
 -DOCE_INCLUDE_PATH=/opt/build/occt740p1/include/opencascade \
 -DOCE_LIB_PATH=/opt/build/occt740p1/lib \
 -DPYTHONOCC_BUILD_TYPE=Release \
 ..
 
RUN ninja install

#######################
# Run pythonocc tests #
#######################
WORKDIR /opt/build/pythonocc-core/test
RUN python core_wrapper_features_unittest.py

##############################
# Install pythonocc examples #
###############################
WORKDIR /opt/build/
RUN git clone https://github.com/tpaviot/pythonocc-demos
WORKDIR /opt/build/pythonocc-demos
RUN git checkout web3d2020
RUN cp -r /opt/build/pythonocc-demos/web3d2020-nb /home/jovyan/work

#############
# pythreejs #
#############
WORKDIR /opt/build
RUN git clone https://github.com/jovyan/pythreejs
WORKDIR /opt/build/pythreejs
RUN git checkout 2.2.0
RUN chown -R jovyan .
USER jovyan
RUN /opt/conda/bin/pip install --user -e .
WORKDIR /opt/build/pythreejs/js
RUN npm run autogen
RUN npm run build:all
USER root
RUN jupyter nbextension install --py --symlink --sys-prefix pythreejs
RUN jupyter nbextension enable pythreejs --py --sys-prefix

########
# gmsh #
########
WORKDIR /opt/build
RUN git clone https://gitlab.onelab.info/gmsh/gmsh
WORKDIR /opt/build/gmsh
RUN git checkout gmsh_4_6_0
WORKDIR /opt/build/gmsh/build

RUN cmake \
 -DCMAKE_BUilD_TYPE=Release \
 -DENABLE_OCC=ON \
 -DENABLE_OCC_CAF=ON \
 -DCMAKE_INSTALL_PREFIX=/usr/local \
 ..

RUN make -j3 && make install

################
# IfcOpenShell #
################
WORKDIR /opt/build
RUN git clone https://github.com/tpaviot/IfcOpenShell
WORKDIR /opt/build/IfcOpenShell
RUN git submodule update --init --remote --recursive
RUN git checkout v0.6.0
WORKDIR /opt/build/IfcOpenShell/build

RUN cmake -G Ninja \
 -DCOLLADA_SUPPORT=OFF \
 -DBUILD_EXAMPLES=OFF \
 -DOCC_INCLUDE_DIR=/opt/build/occt740p1/include/opencascade \
 -DOCC_LIBRARY_DIR=/opt/build/occt740p1/lib \
 -DLIBXML2_INCLUDE_DIR:PATH=/usr/include/libxml2 \
 -DLIBXML2_LIBRARIES=xml2 \
 -DPYTHON_LIBRARY=/opt/conda/lib/libpython3.7m.so \
 -DPYTHON_INCLUDE_DIR=/opt/conda/include/python3.7m \
 -DPYTHON_EXECUTABLE=/opt/conda/bin/python \
 ../cmake
 
RUN ninja install

USER root
RUN echo "c.NotebookApp.tornado_settings = {'websocket_max_message_size': 100 * 1024 * 1024}" > "/etc/jupyter/jupyter_notebook_config.py"

#####################
# back to user mode #
#####################
USER jovyan

WORKDIR /home/jovyan/work/web3d2020-nb
 