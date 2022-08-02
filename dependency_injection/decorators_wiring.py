import other_file
from provider import Provider, provider


@provider.register(key="injected_f")
def injected_f():
    print(f"injected_f from {provider}")


@provider.register
class Test:
    def __init__(self) -> None:
        print("Test")

    def func1(self):
        print("Hi there")


if __name__ == "__main__":
    print(provider)

    for k, v in provider.resources.items():
        print(k, v)

    t = provider.get(Test)()
    t.foo()
