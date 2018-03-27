/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.generator.internal

import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.IComponentConfiguration
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import java.util.HashMap
import java.util.Map
import java.util.NoSuchElementException
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.Expression
import org.yakindu.base.expressions.expressions.FeatureCall
import org.yakindu.base.types.Enumerator

class MapBasedComponentConfiguration implements IComponentConfiguration {
	
	private static class ConfigItemValue {
		public final Expression value;
		public final boolean isDefault;
		
		new(Expression value, boolean isDefault) {
			this.value = value;
			this.isDefault = isDefault;
		}
	}
	
	
	private final Map<String, ConfigItemValue> configurationItems;
	
	new(AbstractSystemResource resource, CompilationContext context) {
		configurationItems = new HashMap();
		
		// add defaults
		for(configItem : resource.configurationItems) {
			val defaultValue = configItem.defaultValue;
			if(defaultValue !== null) {
				configurationItems.put(configItem.name, new ConfigItemValue(defaultValue, true));
			}
		}
		
		// add user specified values
		val setup = context.getSetupFor(resource);
		if(setup !== null) {
			for(value : setup.configurationItemValues) {
				configurationItems.put(value.item.name, new ConfigItemValue(value.value, false));
			}
		}
	}
	
	override exists(String key) {
		return configurationItems.containsKey(key);
	}
	
	override getBoolean(String key) {
		val expr = getExpression(key)?.reduce;
		if(expr instanceof Boolean) {
			return expr;
		} else {
			return null;
		}
	}
	
	override getEnumerator(String key) {
		val expr = getExpression(key)?.reduce;
		if(expr instanceof Enumerator) {
			return expr;
		} else {
			return null;
		}
	}
	
	override getInteger(String key) {
		val expr = getExpression(key)?.reduce;
		if(expr instanceof Integer) {
			return expr;
		} else {
			return null;
		}
	}
	
	override getKeys() {
		return configurationItems.keySet;
	}
	
	override getString(String key) {
		val expr = getExpression(key)?.reduce;
		if(expr instanceof String) {
			return expr;
		} else {
			return null;
		}
	}
	
	override isDefault(String key) throws NoSuchElementException {
		return configurationItems.get(key).isDefault;
	}
	
	override getExpression(String key) {
		return configurationItems.getOrDefault(key, null)?.value;
	}
	
	
	/**
	 * Reduces an expression to it's root value. This function is useful when generating
	 * code from configuration item values. It behaves as follows:
	 *   if expression is FeatureCall: return expression.feature
	 *   if expression is ElementReferenceExpression: return reference
	 *   if expression is not null: return staticValueOf(expression)
	 *   else null
	 * 
	 */
	protected static def reduce(Expression expression) {
		return if(expression instanceof FeatureCall) {
			expression.feature;
		} else if(expression instanceof ElementReferenceExpression) {
			expression.reference;
		} else if(expression !== null) {
			StaticValueInferrer.infer(expression, [x | ])
		} else {
			null;
		};
	}
	
}