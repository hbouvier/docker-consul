configuration := conf/ca_config
country   :=  $(shell cat ${configuration} | grep country   | cut -f2 -d=)
province  :=  $(shell cat ${configuration} | grep province  | cut -f2 -d=)
city      :=  $(shell cat ${configuration} | grep city      | cut -f2 -d=)
company   :=  $(shell cat ${configuration} | grep company   | cut -f2 -d=)
division  :=  $(shell cat ${configuration} | grep division  | cut -f2 -d=)
hostname  :=  $(shell cat ${configuration} | grep hostname  | cut -f2 -d=)
email     :=  $(shell cat ${configuration} | grep email     | cut -f2 -d=)
challenge :=  $(shell cat ${configuration} | grep challenge | cut -f2 -d=)
cie       :=  $(shell echo ${company} | awk '{print $$1}')

all: etc/consul.d/ssl/ca.cert etc/consul.d/ssl/consul.cert etc/consul.d/ssl/consul.key

help:
	@echo 'make regenerate ==> regenerate the consul certificates'

clean:
	@rm -f etc/consul.d/ssl/ca.cert etc/consul.d/ssl/consul.cert etc/consul.d/ssl/consul.key \
		   etc/consul.d/ssl/CA/consul.cert etc/consul.d/ssl/CA/consul.key etc/consul.d/ssl/CA/consul.csr
	@printf "clean ... [OK]\n"

regenerate: clean all

mega-clean:
	@rm -rf etc
	@printf "CA certificated destroyed forever ... [OK]\n"

etc/consul.d/ssl/CA/.dir:
	@printf "Create CA directory ..."
	@mkdir -p etc/consul.d/ssl/CA
	@touch etc/consul.d/ssl/CA/.dir
	@chmod 0700 etc/consul.d/ssl/CA
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/serial: etc/consul.d/ssl/CA/.dir
	@printf "Create CA serial ..."
	@echo "000a" > etc/consul.d/ssl/CA/serial
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/certindex: etc/consul.d/ssl/CA/.dir
	@printf "Create CA certificate index ..."
	@touch etc/consul.d/ssl/CA/certindex
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/ca.cert etc/consul.d/ssl/CA/privkey.pem: etc/consul.d/ssl/CA/.dir etc/consul.d/ssl/CA/serial etc/consul.d/ssl/CA/certindex
	@printf "Create CA certificate ..."
	@cd etc/consul.d/ssl/CA && \
	../../../../bin/self-sign-root-certificate "${country}" "${province}" "${city}" "${company}" "${division}" "${hostname}" "${email}" >& /dev/null
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/consul.csr etc/consul.d/ssl/CA/consul.key: etc/consul.d/ssl/CA/$(cie).conf etc/consul.d/ssl/CA/privkey.pem etc/consul.d/ssl/CA/ca.cert
	@printf "Create CA signing request ..."
	@cd etc/consul.d/ssl/CA && \
	../../../../bin/wildcard-certificate-signing-request "${country}" "${province}" "${city}" "${company}" "${division}" "${hostname}" "${email}" "${challenge}"  >& /dev/null
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/consul.cert: etc/consul.d/ssl/CA/consul.csr
	@printf "Create signing Consul certificate ..."
	@cd etc/consul.d/ssl/CA && \
	openssl ca -batch -config ${cie}.conf -notext -in consul.csr -out consul.cert  >& /dev/null
	@printf "... [OK]\n"

etc/consul.d/ssl/CA/$(cie).conf:
	@printf "Creating ${cie}.conf ..."
	@printf "[ ca ] \ndefault_ca = ${cie}\n\n" > etc/consul.d/ssl/CA/${cie}.conf
	@printf "."
	@printf "[ ${cie} ]\nunique_subject = no\nnew_certs_dir = .\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "certificate = ca.cert\ndatabase = certindex\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "private_key = privkey.pem\nserial = serial\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "default_days = 36500\ndefault_md = sha1\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "policy = ${cie}_policy\nx509_extensions = ${cie}_extensions\n\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "."
	@printf "[ ${cie}_policy ]\ncommonName = supplied\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "stateOrProvinceName = supplied\ncountryName = supplied\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "emailAddress = optional\norganizationName = supplied\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "organizationalUnitName = optional\n\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "."
	@printf "[ ${cie}_extensions ]\nbasicConstraints = CA:false\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "subjectKeyIdentifier = hash\nauthorityKeyIdentifier = keyid:always\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "keyUsage = digitalSignature,keyEncipherment\nextendedKeyUsage = serverAuth,clientAuth\n\n" >> etc/consul.d/ssl/CA/${cie}.conf
	@printf "... [OK]\n"

etc/consul.d/ssl/ca.cert: etc/consul.d/ssl/CA/ca.cert
	@printf "installing ca certificate ..."
	@cp etc/consul.d/ssl/CA/ca.cert etc/consul.d/ssl/ca.cert
	@printf "... [OK]\n"

etc/consul.d/ssl/consul.key: etc/consul.d/ssl/CA/consul.key
	@printf "installing consul private key ..."
	@cp etc/consul.d/ssl/CA/consul.key etc/consul.d/ssl/consul.key
	@printf "... [OK]\n"

etc/consul.d/ssl/consul.cert: etc/consul.d/ssl/CA/consul.cert
	@printf "installing consul certificate ..."
	@cp etc/consul.d/ssl/CA/consul.cert etc/consul.d/ssl/consul.cert
	@printf "... [OK]\n"


