#! /opt/homebrew/bin/python3

from datetime import date
import os
import re

# Get current working directory
directory = os.getcwd()

# Copyright information to be added
copyright = """<?php
/**
* Copyright (c) """ + str(date.today().year) + """ ApexCode
* All rights reserved.

* The contents of this file may not be reproduced, distributed or modified without prior written permission from ApexCode.
* Unauthorized use and distribution of this code is strictly prohibited.
*/"""

# Iterate through all PHP files in the directory
for filename in os.listdir(directory):
    if filename.endswith(".php"):
        # Open the file in read mode
        with open(os.path.join(directory, filename), "r") as f:
            # Read the contents of the file
            filedata = f.read()

        # If the file already has a copyright, skip it
        if "Copyright (c)" in filedata:
            continue

        # Replace the opening PHP tag with an empty string
        filedata = re.sub(r"<\?php","", filedata)

        # Insert the copyright information at the top of the file
        filedata = copyright + filedata

        # Open the file in write mode
        with open(os.path.join(directory, filename), "w") as f:
            # Write the modified contents to the file
            f.write(filedata)
