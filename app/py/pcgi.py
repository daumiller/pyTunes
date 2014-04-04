import os
import json
import cgi, cgitb

params = []

# ==============================================================================
def init(traceback=False):
    global params
    if traceback:
        cgitb.enable()
    params = cgi.parse()


# ==============================================================================
def get_remote():
    user, addr = None, None
    if 'REMOTE_USER' in os.environ:
        user = os.environ['REMOVE_USER']
    if 'REMOTE_ADDR' in os.environ:
        addr = os.environ['REMOTE_ADDR']
    return user, addr


# ==============================================================================
def has_param(name):
    return name in params

def get_param(name):
    return params[name][0]

def get_param_default(name, default=None):
    if not name in params:
        return default
    return params[name][0]

def set_param(name, value):
    params[name] = [value]


# ==============================================================================
def response(body, type = 'text/plain; charset=utf-8'):
    print(''.join(['Status: 200\r\nContent-Type: ', type, '\r\n\r\n', body]))

def response_html(body):
    print(''.join(['Status: 200\r\nContent-Type: text/html; charset=utf-8\r\n\r\n', body]))

def response_object(**props):
    print(''.join(['Status: 200\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n', json.dumps(props)]))

def response_404():
    print("Status: 404 Not Found\r\n\r\n")


# ==============================================================================
# ------------------------------------------------------------------------------
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
