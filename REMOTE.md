sudo docker run -it -p 8080:8888 -p 6006:6006 -v $(pwd):/home/timothygo/work jetson-tf2-jupyter

ssh -N -L localhost:8000:localhost:8080 user@192.168.
