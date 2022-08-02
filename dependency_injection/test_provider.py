import pytest
from provider import Provider, provider


class TestClass:
    pass


@provider.register
class DecoratedClass:
    pass


@provider.register(key="custom_key")
class DecoratedKeyClass:
    pass


def test__validate_single_instance():
    provider1 = Provider()
    provider2 = Provider()

    assert provider.instance is provider1.instance
    assert provider.instance is provider2.instance
    assert provider1.instance is provider2.instance


def test_register_method():
    provider.register(key='func', resource=lambda: "test")

    assert provider.get('func')() == "test"


def test__register_class__get_by_type():
    provider.register(TestClass)

    instance = provider.get(TestClass)()

    assert isinstance(instance, TestClass)


def test__register_with_key__get_with_key():
    provider.register(TestClass, key='foo')

    instance = provider.get('foo')()

    assert isinstance(instance, TestClass)


def test__get_unknown__returns_none():
    instance = provider.get('not_here')

    assert instance is None


def test__register_twice__exception_thrown():
    provider.register(TestClass, key='cause_error')

    with pytest.raises(KeyError):
        provider.register(TestClass, key='cause_error')


@pytest.mark.parametrize("lookup_key, expected_class", [
    (DecoratedClass, DecoratedClass),
    ("custom_key", DecoratedKeyClass)
])
def test__decorated_class__get_key(lookup_key, expected_class):
    instance = provider.get(lookup_key)()

    assert isinstance(instance, expected_class)
