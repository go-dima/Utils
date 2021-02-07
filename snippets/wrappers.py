#!/bin/python3

import functools
from datetime import datetime
from unittest import mock


class MyRequest():
    pass


class ClassError(Exception):
    pass


class SomeMockedClass():
    def __init__():
        pass

    def close(self):
        pass

    def send_request(self):
        pass


class SomeMockedService():
    def get_id():
        pass


def mock_class_lifecycle(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        with mock.patch.object(SomeMockedClass, "__init__") as mocked_class_init, \
                mock.patch.object(SomeMockedClass, "close") as mocked_class_close:
            mocked_class_init.return_value = None
            mocked_class_close.return_value = None

            return func(*args, **kwargs)

    return wrapper


def mock_class_method_with_value(mocked_class, mocked_method_name, return_value):
    def wrapped_with_parameter(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            with mock.patch.object(mocked_class, mocked_method_name) as mocked_method:
                mocked_method.return_value = return_value
                return func(*args, **kwargs)

        return wrapper

    return wrapped_with_parameter


@mock_class_lifecycle
@mock_class_method_with_value(SomeMockedService, "get_id", "8")
def test_class__when_response_500__exception_thrown(self):
    request = MyRequest(myId="some_random_id")

    with mock.patch.object(SomeMockedClass, "send_request") as mocked_class_send_request:
        mocked_class_send_request.return_value = 500

        with self.assertRaises(ClassError):
            self.logic_handler.resend(request)


def timestamp():
    return datetime.now().strftime('%y%m%d_%H%M%S')
