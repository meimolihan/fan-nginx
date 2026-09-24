package com.fan.ext;

import java.util.List;

import com.fan.model.Cert;
import com.fan.model.CertCode;

public class CertExt {
	Cert cert;
	
	List<CertCode> certCodes;

	public Cert getCert() {
		return cert;
	}

	public void setCert(Cert cert) {
		this.cert = cert;
	}

	public List<CertCode> getCertCodes() {
		return certCodes;
	}

	public void setCertCodes(List<CertCode> certCodes) {
		this.certCodes = certCodes;
	}
	
	
}
