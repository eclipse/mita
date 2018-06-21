/** 
 * Copyright (c) 2017 committers of YAKINDU and others. 
 * All rights reserved. This program and the accompanying materials 
 * are made available under the terms of the Eclipse Public License v1.0 
 * which accompanies this distribution, and is available at 
 * http://www.eclipse.org/legal/epl-v10.html 
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 *
*/
package org.eclipse.mita.base.expressions.terminals;

import org.eclipse.xtext.conversion.ValueConverterException;
import org.eclipse.xtext.conversion.impl.AbstractLexerBasedConverter;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.util.Strings;

/**
 * 
 * @author andreas muelder - Initial contribution and API
 * 
 */
public class BinaryValueConverter extends AbstractLexerBasedConverter<Integer> {

	public static final String BINARY_PREFIX = "0b";
	
	public Integer toValue(String string, INode node) {

		if (Strings.isEmpty(string))
			throw new ValueConverterException("Couldn't convert empty string to number.", node, null);

		try {
			// perform the conversion with string index 2 since the prefix is always '0x'
			return Integer.parseInt(string.substring(2), 2);
		} catch ( NumberFormatException e ) {
			throw new ValueConverterException("Couldn't convert '" + string + "' to number.", node, null);
		}
	}

	@Override
	protected String toEscapedString(Integer value) {
		if (value < 0) { 
			return "-" + BINARY_PREFIX + Integer.toString( value * -1, 2).toUpperCase();

		}
		return BINARY_PREFIX + Integer.toString(value, 2).toUpperCase();
	}
	
	

}
