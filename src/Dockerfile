FROM base_image 
ARG xgboost_path
COPY code/serve.py $xgboost_path
COPY code/serve_utils.py $xgboost_path 
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt && rm /requirements.txt

