package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

@Table
public class Credit extends BaseModel {
	/**
	 * 远程调用token
	 */
	String key;

	String adminId;
	
	public String getAdminId() {
		return adminId;
	}

	public void setAdminId(String adminId) {
		this.adminId = adminId;
	}

	public String getKey() {
		return key;
	}

	public void setKey(String key) {
		this.key = key;
	}


}
