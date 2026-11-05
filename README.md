# Sonda — app iOS para o seu slskd

Cliente nativo de monitoramento e controle para o slskd rodando no homelab.
Não baixa nada no telefone: busca, fila e transferência acontecem no servidor,
o app só comanda e mostra o estado. É o oposto do colon3 nesse ponto, e é
justamente o que resolve download longo com a tela apagada.

## O que faz

- Login por host + usuário + senha do slskd (JWT em `/api/v0/session`), senha no Keychain.
- Dashboard: estado do servidor (conectado/logado), endereço, versão do slskd, conta,
  pastas e arquivos compartilhados, rede distribuída, tráfego atual.
- Conectar/desconectar o servidor (`PUT /api/v0/server`).
- Busca com `includeResponses=true`, resultados agrupados por peer, slot livre e tamanho de fila,
  enfileirar arquivo por arquivo.
- Transferências: progresso, velocidade, ETA, estado em português, cancelar por swipe.
- Atualização automática a cada 3s enquanto o app está em primeiro plano.

## O que não faz (ainda)

- Chat/salas e browse de usuário (a API existe: `/api/v0/conversations`, `/hub/application`).
- Tempo real por SignalR: os hubs `/hub/application` e `/hub/logs` existem no slskd 0.26.2,
  mas a primeira versão usa polling de 3s para não depender de implementação de protocolo.
- Notificação em background: o `BGTaskScheduler` está declarado, mas não agendado.

## Build

Sem Mac local, o projeto compila em CI (GitHub Actions, `macos-15`): o workflow
`.github/workflows/build.yml` gera `Sonda-unsigned.ipa` como artefato.

Em qualquer Mac com Xcode:

```
brew install xcodegen
xcodegen generate
xcodebuild -project Sonda.xcodeproj -scheme Sonda -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
mkdir -p out/Payload && cp -R build/Build/Products/Release-iphoneos/Sonda.app out/Payload/ && (cd out && zip -qry ../Sonda-unsigned.ipa Payload)
```

Instalação do IPA sem assinatura: SideStore/AltStore/Sideloadly assinam com o seu Apple ID
no aparelho (conta grátis: 7 dias, 3 apps).

## Verificação do contrato da API

`tools/conformance.py` bate no slskd real e confere, campo por campo, que a resposta
tem os tipos que os modelos Swift decodificam. Rode antes de compilar:

```
python3 tools/conformance.py --host http://192.168.1.43:5030 --user <usuario> --password <senha>
```

Resultado da última execução contra slskd 0.26.2: **64/64 verificações passaram**.

## Estrutura

```
project.yml                 projeto XcodeGen (iOS 18, sem dependências externas)
Sources/Models.swift        Codable + formatação
Sources/SlskdClient.swift   actor sobre a API v0 (token, retry em 401)
Sources/AppStore.swift      estado observável + polling
Sources/Keychain.swift      credencial no Keychain
Sources/Views/*.swift       Login, Servidor, Buscar, Transferências, Ajustes
Resources/Info.plist        NSLocalNetworkUsageDescription + ATS para HTTP na LAN
tools/conformance.py        teste de contrato contra o servidor real
```

## Endpoints usados

| Método | Rota | Uso |
|---|---|---|
| POST | `/api/v0/session` | obter JWT |
| GET | `/api/v0/server` | estado |
| PUT | `/api/v0/server` | conectar/desconectar |
| GET | `/api/v0/application` | versão, conta, shares, rede distribuída |
| POST | `/api/v0/searches` | iniciar busca |
| GET | `/api/v0/searches/{id}?includeResponses=true` | resultados |
| DELETE | `/api/v0/searches/{id}` | limpar busca |
| GET | `/api/v0/transfers/downloads` | fila e progresso |
| POST | `/api/v0/transfers/downloads/{usuario}` | enfileirar `[{filename,size}]` |
| DELETE | `/api/v0/transfers/downloads/{usuario}/{id}?remove=false` | cancelar |
| GET | `/api/v0/transfers/uploads` | uploads |
| GET | `/api/v0/conversations` | conversas abertas |

## Avisos

- O app fala HTTP puro na LAN; o `Info.plist` libera ATS para isso. Fora da rede local,
  use Tailscale ou coloque o slskd atrás de HTTPS.
- A credencial padrão do slskd (usuário `slskd`) e `remoteConfiguration: true` deixam
  qualquer host da rede mudar a configuração. Troque antes de expor.
