#!/bin/bash

# Copyright (c) 2017-2019 Vanessa Sochat

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

python /code/helpers/slurm2json.py "$@" --outfile /tmp/machines.json
RETVAL=$?

# If successful generation, create temporary directory will all content
if [ "${RETVAL}" == "0" ]; then
    echo "Successful generation! Writing output to /data..."
    for file in "index.html" "README.md" "LICENSE"
       do
       cp "/code/${file}" /data/"${file}"
    done
    cp -R /code/assets /data/assets
    mkdir -p /data/data
    mv /tmp/machines.json /data/data/machines.json
    chmod -R g+rwX /data
    tree /data -L 1
fi
