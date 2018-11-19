package org.eclipse.mita.base.util

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStreamReader
import java.io.Reader
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream
import java.io.BufferedReader

// See https://stackoverflow.com/questions/16351668/compression-and-decompression-of-string-data-in-java
class GZipper {
	static def String compress(String s) {
		val outStream = new ByteArrayOutputStream();
		val gzipStream = new GZIPOutputStream(outStream);
		gzipStream.write(s.getBytes("UTF-8"));
		gzipStream.flush();
		gzipStream.close();
		
		return outStream.toString("ISO-8859-1");
	}
	
	static def String decompress(String s) {
		val inStream = new ByteArrayInputStream(s.getBytes("ISO-8859-1"));
		val gzipStream = new GZIPInputStream(inStream);
		val reader = new BufferedReader(new InputStreamReader(gzipStream, "UTF-8"));
		val result = new StringBuilder();
		while(reader.ready) {
			result.append(reader.readLine);
		}
		
		return result.toString();
	}
	
}