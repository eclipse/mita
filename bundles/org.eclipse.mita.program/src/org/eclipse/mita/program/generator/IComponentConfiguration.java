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

package org.eclipse.mita.program.generator;

import java.util.NoSuchElementException;

import org.yakindu.base.expressions.expressions.Expression;
import org.yakindu.base.types.Enumerator;

/**
 * Component configurations describe the setup of a component based on user specification
 * and platform defaults.
 */
public interface IComponentConfiguration {

	/**
	 * @return a list of configuration item keys available
	 */
	public Iterable<String> getKeys();
	
	/**
	 * @return true if this configuration contains the key
	 */
	public boolean exists(String key);
	
	/**
	 * @return true if the value for this configuration key is the default value configured in the platform
	 */
	public boolean isDefault(String key) throws NoSuchElementException;

	/**
	 * Retrieves a string value from this configuration. If the key is unknown or the value stored with this key
	 * is not a string, null is returned (use {@link #exists(String)} to check if the key exists in the first place.)
	 * If the user did not explicitly specify this configuration item, but a default exists in the platform, the
	 * default value is used (see {@link #isDefault(String)}). 
	 * 
	 * @param key the key to get a value for
	 * @return the value of the configuration item named key
	 */
	public String getString(String key);
	
	/**
	 * Retrieves a boolean value from this configuration. If the key is unknown or the value stored with this key
	 * is not a boolean, null is returned (use {@link #exists(String)} to check if the key exists in the first place.)
	 * If the user did not explicitly specify this configuration item, but a default exists in the platform, the
	 * default value is used (see {@link #isDefault(String)}). 
	 * 
	 * @param key the key to get a value for
	 * @return the value of the configuration item named key
	 */
	public Boolean getBoolean(String key);
	
	/**
	 * Retrieves an integer value from this configuration. If the key is unknown or the value stored with this key
	 * is not an integer, null is returned (use {@link #exists(String)} to check if the key exists in the first place.)
	 * If the user did not explicitly specify this configuration item, but a default exists in the platform, the
	 * default value is used (see {@link #isDefault(String)}). 
	 * 
	 * @param key the key to get a value for
	 * @return the value of the configuration item named key
	 */
	public Integer getInteger(String key);
	
	/**
	 * Retrieves an enumerator value from this configuration. If the key is unknown or the value stored with this key
	 * is not an enumerator, null is returned (use {@link #exists(String)} to check if the key exists in the first place.)
	 * If the user did not explicitly specify this configuration item, but a default exists in the platform, the
	 * default value is used (see {@link #isDefault(String)}). 
	 * 
	 * @param key the key to get a value for
	 * @return the value of the configuration item named key
	 */
	public Enumerator getEnumerator(String key);
	
	/**
	 * Retrieves the raw expression from this configuration. If the key is unknown or does not have a default,
	 * null is returned (use {@link #exists(String)} to check if the key exists in the first place.)
	 * If the user did not explicitly specify this configuration item, but a default exists in the platform, the
	 * default value is used (see {@link #isDefault(String)}). 
	 * 
	 * @param key the key to get a value for
	 * @return the value of the configuration item named key
	 */
	public Expression getExpression(String key);
	
}
