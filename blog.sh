#!/bin/bash

# Update and install dependencies
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv

# Clone the repository and set up the Flask app
git clone https://github.com/kura-labs-org/C5-Cybersecurity-WL1.git /home/ubuntu/microblog
cd /home/ubuntu/microblog
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

flask run --host=0.0.0.0 > flask.log 2>&1 &