# Secretly TLS proxy

A small relay that helps people reach Secretly where its servers are blocked.
It follows the Signal TLS proxy design: your server terminates one TLS layer
with your own certificate; inside it is a second TLS connection that the app
established with the real Secretly server. You cannot read or alter the
traffic — the app verifies the real server's certificate through your proxy —
and the proxy does not log who used it.

What you need: a Linux host with Docker, a domain name pointing at it, and
ports 80 (for the certificate) and 443 open.

```bash
git clone https://github.com/Arkhanhel/Secretly.git
cd Secretly/server/proxy/tlsproxy
./init-certificate.sh proxy.example.org   # your domain
docker compose up -d
```

Then share the link `secretly://proxy#proxy.example.org`. In the app it goes
to Settings → Network → Proxy. From the outside your server looks like an
ordinary HTTPS site; the app's traffic is indistinguishable from that site's
traffic.

Limits, stated plainly: a censor who learns your domain can block it like any
other site, so proxies are shared quietly and replaced when blocked; the
proxy forwards only `keys.secretlyapp.com` and `relay.secretlyapp.com` and
drops everything else; attachments and calls through a proxy are slower.

# Прокси Secretly для волонтёров

Небольшой ретранслятор, который помогает людям дотянуться до Secretly там,
где его серверы закрыты. Схема как у TLS-прокси Signal: ваш сервер снимает
один слой TLS своим сертификатом, а внутри остаётся второе TLS-соединение,
которое приложение установило с настоящим сервером. Прочитать или подменить
трафик нельзя — приложение проверяет сертификат настоящего сервера сквозь
ваш прокси, — а прокси не ведёт журнал, кто им пользовался.

Нужны: Linux с Docker, доменное имя, направленное на него, открытые порты 80
(для сертификата) и 443.

```bash
git clone https://github.com/Arkhanhel/Secretly.git
cd Secretly/server/proxy/tlsproxy
./init-certificate.sh proxy.example.org   # ваш домен
docker compose up -d
```

Дальше поделитесь ссылкой `secretly://proxy#proxy.example.org` — в приложении
она попадает в Настройки → Сеть → Прокси. Снаружи ваш сервер выглядит как
обычный сайт по HTTPS; трафик приложения неотличим от трафика этого сайта.

Пределы, честно: цензор, узнавший ваш домен, заблокирует его как любой сайт,
поэтому прокси раздают тихо и меняют после блокировки; прокси пропускает
только `keys.secretlyapp.com` и `relay.secretlyapp.com`, остальное
обрывает; вложения и звонки через прокси медленнее.
