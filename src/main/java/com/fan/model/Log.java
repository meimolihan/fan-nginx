package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

@Table
public class Log extends BaseModel{
	String path;

	public String getPath() {
		return path;
	}

	public void setPath(String path) {
		this.path = path;
	}
	
	
	
}
