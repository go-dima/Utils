from provider import Provider

provider = Provider()


@provider.register
def injected_g():
    print(f"injected_g from {provider}")
    print("injected_g")
