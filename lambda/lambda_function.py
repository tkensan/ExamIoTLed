import json
import numbers

import boto3


shadow_update_data = {'state': {'reported': {'heartbeat': 0}}}

def shadow_get_decode(dct):
    n = dct['timestamp']
    l = dct['metadata']['reported']['light']['timestamp']
    validate_int_nonegative(n)
    validate_int_nonegative(l)
    assert n >= l
    return (n, l)

def shadow_get_encode(now, last):
    p = {
        'timestamp': now,
        'metadata': {'reported': {'light': {'timestamp': last}}} }
    return p

def payload_get(response):
    b = response['payload']
    p = json.loads(b.read())
    print('payload: ', p)
    return p

def payload_put(dct):
    return json.dumps(dct)

def validate_int(value):
    if not isinstance(value, numbers.Integral):
        raise TypeError
    elif isinstance(value, bool):
        raise TypeError

def validate_int_nonegative(value):
    validate_int(value)
    assert value >= 0

def lambda_handler(event, context):
    name = event['thingname']
    limit = event['limit']
    print('thing: {}, limit: {}'.format(name, limit))
    validate_int(limit)
    iot = boto3.client('iot-data')
    r = iot.get_thing_shadow(thingName=name)
    p = payload_get(r)
    now, last = shadow_get_decode(p)
    delta = now - last
    print('delta: ', delta)
    if delta > limit:
        print('Health check failed!')
        iot.update_thing_shadow(
            thingName=name, payload=payload_put(shadow_update_data))
    return delta

