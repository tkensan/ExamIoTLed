import argparse
import json

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

class ExamIoTLedDevice:
    def __init__(self, shadow):
        self._shadow = shadow
        self._connected = 1
        self._heartbeat = 1
        self._power = 1
        self._light = 0
        self.shadow_update()
    def shadow_update(self):
        d = ShadowPayload.encode(
            self._connected, self._power, self._light, self._heartbeat)
        self._shadow.shadowUpdate(d, None, 5)
    def get(self):
        print("Get")
        self.shadow_update()

class MainHandler(tornado.web.RequestHandler):
    def initialize(self, device):
        self._device = device
    def get(self):
        self._device.get()
        self.write("Hello, Get")

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
    s.connect()
    return s.createShadowHandlerWithName(a.thingName, True)

def make_webapp(device):
    return tornado.web.Application([
        (r"/", MainHandler, dict(device=device)), ])

if __name__ == "__main__":
    shadow = make_shadow()
    device = ExamIoTLedDevice(shadow)
    webapp = make_webapp(device)
    webapp.listen(8888)
    tornado.ioloop.IOLoop.current().start()
