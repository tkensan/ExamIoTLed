import argparse
import json
import time

import tornado.escape
import tornado.ioloop
import tornado.web

from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTShadowClient


class ShadowPayload:
    @staticmethod
    def encode(connected, power, light, heartbeat):
        d = {'state': {'reported': {
            'connected': connected,
            'power': power,
            'light': light,
            'heartbeat': heartbeat,
            }}}
        print(d)
        return json.dumps(d)
    @staticmethod
    def decode(payload):
        d = json.loads(payload)
        print(d)
        return d['state']['light']

class ExamIoTLedDevice:
    def __init__(self, shadow, ioloop):
        self._ioloop = ioloop
        self._shadow = shadow
        self.shadow_delta_reg()
        print("Waiting for delta callback to be registered ...")
        time.sleep(10) # wait until delta callback is ready to receive
        self._connected = 1
        self._heartbeat = 1
        self._power = 1
        self._light = 0
        self.shadow_update()
    def shadow_delta_reg(self):
        self._shadow.shadowRegisterDeltaCallback(self.shadow_delta_cb)
    def shadow_delta_cb(self, payload, status, token):
        self._ioloop.add_callback(self.shadow_delta, payload, status, token)
        print("Delta callback added")
    def shadow_delta(self, payload, status, token):
        print("Delta callback: power={}".format(self._power))
        if self._power != 0:
            self._light = ShadowPayload.decode(payload)
            self.shadow_update()
    def shadow_update(self):
        d = ShadowPayload.encode(
            self._connected, self._power, self._light, self._heartbeat)
        self._shadow.shadowUpdate(d, None, 5)
    def get(self):
        print("Get")
        self.shadow_update()
    def put(self, power):
        print("Put")
        self._power = power
        self.shadow_update()

class MainHandler(tornado.web.RequestHandler):
    def initialize(self, device):
        self._device = device
    def get(self):
        self._device.get()
        self.write("Hello, Get")
    def put(self):
        d = tornado.escape.json_decode(self.request.body)
        self._device.put(**d)
        self.write("Hello, Put")

def make_shadow():
    p = argparse.ArgumentParser()
    p.add_argument("-e", "--endpoint", action="store", required=True, dest="host", help="Your AWS IoT custom endpoint")
    p.add_argument("-r", "--rootCA", action="store", required=True, dest="rootCAPath", help="Root CA file path")
    p.add_argument("-c", "--cert", action="store", dest="certificatePath", help="Certificate file path")
    p.add_argument("-k", "--key", action="store", dest="privateKeyPath", help="Private key file path")
    p.add_argument("-n", "--thingName", action="store", dest="thingName", default="ExamIoTLED", help="Targeted thing name")
    p.add_argument("-id", "--clientId", action="store", dest="clientId", default="examIoTLedDevice", help="Targeted client id")
    a = p.parse_args()
    s = AWSIoTMQTTShadowClient(a.clientId)
    s.configureEndpoint(a.host, 8883)
    s.configureCredentials(a.rootCAPath, a.privateKeyPath, a.certificatePath)
    s.configureAutoReconnectBackoffTime(1, 32, 20)
    s.configureConnectDisconnectTimeout(10)  # 10 sec
    s.configureMQTTOperationTimeout(5)  # 5 sec
    print('Configuring last will message with the following payload ...')
    s.configureLastWill("my/things/{}/update".format(a.thingName), ShadowPayload.encode(0, 0, 0, 0), 0)
    s.connect()
    return s.createShadowHandlerWithName(a.thingName, True)

def make_webapp(device):
    return tornado.web.Application([
        (r"/", MainHandler, dict(device=device)), ])

if __name__ == "__main__":
    ioloop = tornado.ioloop.IOLoop.current()
    shadow = make_shadow()
    device = ExamIoTLedDevice(shadow, ioloop)
    webapp = make_webapp(device)
    webapp.listen(8888)
    ioloop.start()
