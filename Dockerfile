# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

ARG BASE_IMAGE=nvcr.io/nvidia/l4t-base:r32.4.4
ARG TENSORFLOW_IMAGE=nvcr.io/nvidia/l4t-tensorflow:r32.5.0-tf2.3-py3

FROM ${TENSORFLOW_IMAGE} as tensorflow
FROM ${BASE_IMAGE}


#
# setup environment
#
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME="/usr/local/cuda"
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
ENV LLVM_CONFIG="/usr/bin/llvm-config-9"
ARG MAKEFLAGS=-j6

RUN printenv


#
# apt packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
          python3-pip \
                  python3-dev \
          python3-matplotlib \
                  build-essential \
                  gfortran \
                  git \
                  cmake \
                  libopenblas-dev \
                  liblapack-dev \
                  libblas-dev \
                  libhdf5-serial-dev \
                  hdf5-tools \
                  libhdf5-dev \
                  zlib1g-dev \
                  zip \
                  libjpeg8-dev \
                  libopenmpi2 \
          openmpi-bin \
          openmpi-common \
                  nodejs \
                  npm \
                  protobuf-compiler \
          libprotoc-dev \
                llvm-9 \
          llvm-9-dev \
    && rm -rf /var/lib/apt/lists/*


#
# OpenCV
#
ARG OPENCV_URL=https://nvidia.box.com/shared/static/5v89u6g5rb62fpz4lh0rz531ajo2t5ef.gz
ARG OPENCV_DEB=OpenCV-4.5.0-aarch64.tar.gz

RUN mkdir opencv && \
    cd opencv && \
    wget --quiet --show-progress --progress=bar:force:noscroll --no-check-certificate ${OPENCV_URL} -O ${OPENCV_DEB} && \
    tar -xzvf ${OPENCV_DEB} && \
    dpkg -i --force-depends *.deb && \
    apt-get update && \
    apt-get install -y -f --no-install-recommends && \
    dpkg -i *.deb && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    cd ../ && \
    rm -rf opencv && \
    cp -r /usr/include/opencv4 /usr/local/include/opencv4 && \
    cp -r /usr/lib/python3.6/dist-packages/cv2 /usr/local/lib/python3.6/dist-packages/cv2


#
# python packages from TF/PyTorch containers
#
COPY --from=tensorflow /usr/local/lib/python2.7/dist-packages/ /usr/local/lib/python2.7/dist-packages/
COPY --from=tensorflow /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages/

#
# python pip packages
#
RUN pip3 install pybind11 --ignore-installed
RUN pip3 install onnx --verbose
RUN pip3 install scipy --verbose
RUN pip3 install scikit-learn --verbose
RUN pip3 install pandas --verbose
RUN pip3 install pycuda --verbose
RUN pip3 install numba --verbose


#
# CuPy
#
ARG CUPY_VERSION=v10.0.0b3
ARG CUPY_NVCC_GENERATE_CODE="arch=compute_53,code=sm_53;arch=compute_62,code=sm_62;arch=compute_72,code=sm_72"

RUN git clone -b ${CUPY_VERSION} --recursive https://github.com/cupy/cupy cupy && \
    cd cupy && \
    pip3 install --no-cache-dir fastrlock && \
    python3 setup.py install --verbose && \
    cd ../ && \
    rm -rf cupy


#
# JupyterLab
#
RUN pip3 install -U pip
RUN pip3 install -U setuptools
RUN pip3 install jupyter jupyterlab --verbose
#RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager@2

RUN jupyter lab --generate-config
RUN python3 -c "from notebook.auth.security import set_password; set_password('nvidia', '/root/.jupyter/jupyter_notebook_config.json')"

CMD /bin/bash -c "jupyter lab --ip 0.0.0.0 --port 8888 --allow-root &> /var/log/jupyter.log" & \
        echo "allow 10 sec for JupyterLab to start @ http://localhost:8888 (password nvidia)" && \
        echo "JupterLab logging location:  /var/log/jupyter.log  (inside the container)" && \
        /bin/bash
