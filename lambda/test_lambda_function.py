import unittest
from unittest.mock import patch

import lambda_function as lf

class TestLambdaHandler(unittest.TestCase):

    thingname = 'testthing'

    @patch('lambda_function.boto3')
    def test_health_ng(self, mock):
        c = {
            'client.return_value'
            '.get_thing_shadow.return_value'
            '.__getitem__.return_value'
            '.read.return_value': lf.payload_put(lf.shadow_get_encode(1, 0)),
            }
        mock.configure_mock(**c)
        d = lf.lambda_handler({'thingname': self.thingname, 'limit': 0}, None)
        self.assertEqual(d, 1)
        mock.client.return_value.update_thing_shadow.assert_called_once_with(
            thingName=self.thingname,
            payload=lf.payload_put(lf.shadow_update_data))

if __name__ == '__main__':
    unittest.main()
