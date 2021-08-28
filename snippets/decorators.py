#!/usr/bin/python3
import functools


def decorate(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        print("pre decorate: " + func.__name__)
        ret_val = func(*args, **kwargs)
        print("post decorate")
        return ret_val
    return wrapper


def undecorated_parameretless():
    print("I have no params!")


@decorate
def decorated_parameretless():
    print("I have no params!")


@decorate
def decorated_w_params(text):
    print("I got " + text)


@decorate
def decorated_w_return(in_value):
    """
    :type in_value: number
    """
    return 2*in_value


if __name__ == '__main__':
    decorated_parameretless()
    print("--------")
    decorated_w_params('Sup')
    print("--------")
    print(decorated_w_return(4))
    print(decorated_w_return('sup'))
    print("--------")
    for foo in [undecorated_parameretless, decorated_parameretless]:
        print(foo.__name__)
        print(foo)
        print("+++++")
