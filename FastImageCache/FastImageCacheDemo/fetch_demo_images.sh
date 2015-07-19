#!/bin/bash

echo "Fetching demo images..."
`curl "https://s3.amazonaws.com/fast-image-cache/demo-images/FICDDemoImage[000-099].jpg" --create-dirs -o "Demo Images/FICDDemoImage#1.jpg" --silent`