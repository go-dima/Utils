import functools


class Provider:
    class _Singelton:
        def __init__(self) -> None:
            self.resources = {}

        def register(self, resource_key, resource):
            print(f"Registered {resource} as {resource_key}")

            if resource_key in self.resources:
                raise KeyError(f"{resource_key} already registered")
            self.resources[resource_key] = resource
            return resource

    instance = None

    def __init__(self) -> None:
        if not Provider.instance:
            Provider.instance = Provider._Singelton()

    def register(self, resource=None, *, key=None):
        @functools.wraps(resource)
        def register_decorator(resource):
            resource_key = resource if key is None else key
            Provider.instance.register(resource_key, resource)
            return resource

        if resource is None:  # decorator called with arguments
            return register_decorator

        return register_decorator(resource)

    def get(self, key):
        return Provider.instance.resources.get(key, None)

    def __getattr__(self, name):
        return getattr(self.instance, name)


provider = Provider()
