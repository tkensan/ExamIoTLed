import unittest
from unittest.mock import patch

from botocore.exceptions import ParamValidationError

import lambda_function as lf

@patch('lambda_function.boto3')
class TestLambdaHandler(unittest.TestCase):

    thingname = 'testthing'
    lambdaevent = {'thingname': thingname, 'limit': 0}
    lambdaevent_nokey = {'limit': 0}
    lambdaparam = {'event': lambdaevent, 'context': None}

    def config_payload(self, now, last):
        c = {
            'client.return_value'
            '.get_thing_shadow.return_value'
            '.__getitem__.return_value'
            '.read.return_value': lf.payload_put(lf.shadow_get_encode(
                now, last)),
            }
        return c

    def config_shadowget(self, effect):
        c = {
            'client.return_value'
            '.get_thing_shadow.side_effect': effect
            }
        return c

    def test_health_ng(self, mock):
        mock.configure_mock(**(self.config_payload(1, 0)))
        d = lf.lambda_handler(**(self.lambdaparam))
        self.assertEqual(d, 1)
        mock.client.return_value.update_thing_shadow.assert_called_once_with(
            thingName=self.thingname,
            payload=lf.payload_put(lf.shadow_update_data))

    def test_health_ok(self, mock):
        mock.configure_mock(**(self.config_payload(1, 1)))
        d = lf.lambda_handler(**(self.lambdaparam))
        self.assertEqual(d, 0)
        mock.client.return_value.update_thing_shadow.assert_not_called()

    def test_timestamp_backward(self, mock):
        mock.configure_mock(**(self.config_payload(0, 1)))
        self.assertRaises(
            AssertionError,
            lf.lambda_handler, event=self.lambdaevent, context=None)
        mock.client.return_value.update_thing_shadow.assert_not_called()

    def test_thingname_nothing(self, mock):
        """
        Test non existing thing name specified.
        """
        # botocore.errorfactory.ResourceNotFoundException in AWS lambda,
        # but use Exception for now
        mock.configure_mock(**(self.config_shadowget(Exception)))
        self.assertRaises(
            Exception,
            lf.lambda_handler, event=self.lambdaevent, context=None)
        mock.client.return_value.update_thing_shadow.assert_not_called()

    def test_thingname_nostr(self, mock):
        """
        Test non string thing name specified.
        """
        mock.configure_mock(**(self.config_shadowget(ParamValidationError(
            report='UnitTest'))))
        self.assertRaises(
            ParamValidationError,
            lf.lambda_handler, event=self.lambdaevent, context=None)
        mock.client.return_value.update_thing_shadow.assert_not_called()

    def test_thingname_nokey(self, mock):
        """
        Test no thing name key available.
        """
        self.assertRaises(
            KeyError,
            lf.lambda_handler, event=self.lambdaevent_nokey, context=None)
        mock.client.return_value.update_thing_shadow.assert_not_called()

if __name__ == '__main__':
    unittest.main()
