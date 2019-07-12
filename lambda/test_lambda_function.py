import unittest
from unittest.mock import patch

import lambda_function as lf

@patch('lambda_function.boto3')
class TestLambdaHandler(unittest.TestCase):

    thingname = 'testthing'
    lambdaevent = {'thingname': thingname, 'limit': 0}

    def config_payload(self, now, last):
        c = {
            'client.return_value'
            '.get_thing_shadow.return_value'
            '.__getitem__.return_value'
            '.read.return_value': lf.payload_put(lf.shadow_get_encode(
                now, last)),
            }
        return c

    def test_health_ng(self, mock):
        mock.configure_mock(**(self.config_payload(1, 0)))
        d = lf.lambda_handler(self.lambdaevent, None)
        self.assertEqual(d, 1)
        mock.client.return_value.update_thing_shadow.assert_called_once_with(
            thingName=self.thingname,
            payload=lf.payload_put(lf.shadow_update_data))

    def test_health_ok(self, mock):
        mock.configure_mock(**(self.config_payload(1, 1)))
        d = lf.lambda_handler(self.lambdaevent, None)
        self.assertEqual(d, 0)
        mock.client.return_value.update_thing_shadow.assert_not_called()

if __name__ == '__main__':
    unittest.main()
