#!/bin/bash

# blog.sh updated for more security

# Update and install dependencies
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv

# Clone the repository and set up the Flask app
git clone https://github.com/kura-labs-org/C5-Cybersecurity-WL1.git /home/ubuntu/microblog
cd /home/ubuntu/microblog
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create a systemd service file for running with Gunicorn
sudo tee /etc/systemd/system/microblog.service << EOF
[Unit]
Description=Microblog Gunicorn Service
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/microblog
Environment="PATH=/home/ubuntu/microblog/venv/bin"
ExecStart=/home/ubuntu/microblog/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 microblog:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl start microblog
sudo systemctl enable microblog

# Check the service status
sudo systemctl status microblog