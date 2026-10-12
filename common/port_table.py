from settings import web_endpoints

if __name__ == "__main__":
    print("| Интерфейс | Адрес |")
    print("|---|---|")
    for name, item in web_endpoints().items():
        print(f"| {name} | https://localhost:{item['external_port']}/ |")
