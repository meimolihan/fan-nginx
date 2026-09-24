package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

@Table
public class Bak extends BaseModel{
	String time;
	String content;


	public String getContent() {
		return content;
	}

	public void setContent(String content) {
		this.content = content;
	}

	public String getTime() {
		return time;
	}

	public void setTime(String time) {
		this.time = time;
	}

}
