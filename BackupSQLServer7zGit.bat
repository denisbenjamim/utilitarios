
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION	
set servidor=NOME_SERVIDOR
set usuarioSQL=USAURIO_BANCO
set passwordSQL=SENHA_USUARIO_BANCO
REM BASES DE DADOS PARA BACKUP SEPARADAS POR ESPACO
set bases=master model
REM DIRETORIO TEMPORARIO PARA ARMAZENAMENTO DOS ARQUIVOS .BAK
set diretorioBackup=D:\Compartilhamento\Backup

REM DIRETORIO PARA ENVIO DO ARQUIVO 7Z APOS A COMPRESSAO
set diretorioRede=\\192.168.1.6\BKP

REM LOCALIZACAO BLAT SOFTWARE PARA ENVIAR EMAIL
REM BLAT PODE SER ENCONTRADO EM https://sourceforge.net/projects/blat/
set blatlocation=C:\blat

REM CONFIGURACOES E-MAIL BLAT
set smtpserver=mail.seudominio.com.br
set port=587
set user=no-reply@seudominio.com.br
set pw=SENHA_EMAIL
set fromaddress=%user%
REM Destinatario de Email
set toaddress=SEUS_DESTINATARIOS
set appname=SQL Backup App

(for %%a in (%bases%) do ( 	
	REM ARMAZENA O BACKUP NA PASTA DE BACKUP
	SqlCmd -S %servidor% -U %usuarioSQL% -P %passwordSQL% -Q "BACKUP DATABASE [%%a] TO disk='%diretorioBackup%\%%a.bak' WITH NOFORMAT, INIT, SKIP, NOREWIND, NOUNLOAD,  STATS = 10"
		
	if not exist "%diretorioBackup%" (
		set subject=Backup error : SQL Backup failed %%a
		set body=SQL Backup failed. !date! !time!
		GOTO SENDMSG
		)
	
		set dia=!date:~0,2!
		set mes=!date:~3,2!
		set ano=!date:~6,4!
		set hora=!time:~0,2!
		set minuto=!time:~3,2!
		set segundos=!time:~6,2! 
		
		REM COMPACTA A BASE DE DADOS ANTES DE COPIAR PARA UMA PASTA NA REDE
		REM a este parametro é para indicar que vai adicionar um arquivo para ser compactado
		REM -t7z indica o tipo de arquivo que deve ser criado
		REM -m0 indica o algoritmo para compactacao
		REM -mx o nivel da compactacao  varia de 0 a 9 sendo 9(Ultra) o mais lento porem o que mais compacta 
		REM -mmt indica quantas threads devem ser usadas, quanto maior o numero mais memoria  vai ser necessaria
		REM -aoa sobreescreve caso o arquivo ja exista
		REM -mfb pode variar de 3 a 258 quanto maior o valor mais ira demorar, porem tera uma compressao maior
		REM -md indica o tamanho do dicionario
		REM -ms indica que sera um arquivo solido e possivel indicar o tamanho do arquivo solito caso necessario
		REM -mhe Ativa ou desativa a criptografia do cabeçalho do arquivo. O modo padrão é ele = off
		REM -sdel indica que ao terminar de compactar caso termine com sucesso, deve deletar o arquivo original
		7z a -t7z -m0=lzma2 -mx=5 -mmt=3 -aoa -mfb=64 -md=64m -ms=on -mhe "%diretorioBackup%\!ano!-!mes!-!dia! !hora!-!minuto!-!segundos!-%%a.7z" "%diretorioBackup%\%%a.bak" -sdel
		
		REM SE O ARQUIVO NAO EXISTIR NO CAMINHO ENTAO SERA ENVIADO UM EMAIL NOTIFICANDO
		if not exist "%diretorioBackup%\!ano!-!mes!-!dia! !hora!-!minuto!-!segundos!-%%a.7z" (
			set subject=Backup error : 7zip failed !ano!-!mes!-!dia! !hora!-!minuto!-!segundos!-%%a.7z
			set body=7zip operation failed. !date! !time! 
			GOTO SENDMSG)
		REM MOVE TODOS OS ARQUIVOS COM EXTENSAO 7z do diretorio de backup para a diretorio na rede		
		robocopy "%diretorioBackup%" "%diretorioRede%" *.7z /s /move

		REM SE O ARQUIVO EXISTIR NO DIREITORIO DA REDE ENTAO SERA ENVIADO UM EMAIL NOTIFICANDO
		IF EXIST "%diretorioRede%\!ano!-!mes!-!dia! !hora!-!minuto!-!segundos!-%%a.7z" (
			set subject=Backup successful !ano!-!mes!-!dia! !hora!-!minuto!-!segundos!-%%a.7z
			set body=Backup successful. !date! !time!
			%blatlocation%\blat.exe -to %toaddress% -i "%appname%" -server %smtpserver% -u %user% -pw %pw% -f %fromaddress% -subject "%appname% : !subject!" -body "!body!")
	)
)
:END
exit

:SENDMSG
%blatlocation%\blat.exe -to %toaddress% -i "%appname%" -server %smtpserver% -u %user% -pw %pw% -f %fromaddress% -subject "%appname% : %subject%" -body "%body%"
GOTO END