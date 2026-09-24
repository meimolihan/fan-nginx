package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

@Table
public class BakSub extends BaseModel{
	String bakId;
	
	String name;
	
	String content;

	public String getBakId() {
		return bakId;
	}

	public void setBakId(String bakId) {
		this.bakId = bakId;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getContent() {
		return content;
	}

	public void setContent(String content) {
		this.content = content;
	}

	
}
