FROM python:3.8
WORKDIR /app
COPY packages.txt /app
RUN pip install -r ./packages.txt
COPY TrainModel.py /app
CMD ["python", "TrainModel.py"]