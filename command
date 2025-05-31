---polezni comandi
cd - eto comanda dlya peremeshenya. esli bez kataloga to vverh po katalogu
cd *katalog*

ls - proverit faili v kataloge
rm -rf *katalog* - ydalit katalog
pwd - polnyi put gde wi nahodites
mkdir - sozhat katalog
cp *istochnik* *zel* - copirovat fail
cat *fail* - vivisti soderzimoe faila
nano *fail* - redaktirovat fail
ping *addres ili domen* - proverit svaz


---zapusk skripta:
expect *imya_skripta.exp*


---kopirovanie failov iz mashini v mashinu
scp -r ConfigForDemo/ user@*ip*:
password (vrode P@ssw0rd)
-na drugoi mashine, na kotoruu delaem kopirovanie
cp /home/user/ConfigForDemo /root/ -r


---chatGPT (slabiy) v terminale:
curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin
tgpt --provider phind "zdes pishem zapros v kovichkah"

tgpt -h - posmotret modelki i tam po melocham

esli vivod bolshoi to usaite comandy:
tgpt --provider phind "zdes pishem zapros v kovichkah" | less
-q


---google v terminale
apt-get install surfraw
surfraw google *zapros*


---cartinki v terminale
dnf install catimg
catimg *image.png*
