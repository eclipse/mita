package org.eclipse.mita.base.expressions.terminals

import org.eclipse.xtext.conversion.impl.AbstractLexerBasedConverter
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.conversion.ValueConverterException

class LongValueConverter extends AbstractLexerBasedConverter<Long> {
	
	override toValue(String string, INode node) throws ValueConverterException {
		if(string.empty) {
			throw new ValueConverterException("Couldn't convert empty string to an int value.", node, null);			
		}
		try {
			val longValue = Long.parseLong(string, 10);
			return longValue;
		} catch (NumberFormatException e) {
			throw new ValueConverterException("Couldn't convert '" + string + "' to an int value.", node, e);
		}
	}
	
}