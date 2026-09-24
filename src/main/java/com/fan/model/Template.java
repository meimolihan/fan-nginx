package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

@Table
public class Template extends BaseModel{
	String name;

	String def; // 默认配置 "" "server" "server1" "server2" "location" "upstream"
	
	
	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getDef() {
		return def;
	}

	public void setDef(String def) {
		this.def = def;
	}
	
	
}
