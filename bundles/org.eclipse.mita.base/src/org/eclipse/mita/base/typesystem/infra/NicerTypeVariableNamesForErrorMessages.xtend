/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import java.util.Random
import java.util.stream.Collectors
import java.util.stream.IntStream
import org.eclipse.core.runtime.Assert
import org.eclipse.xtext.xbase.lib.Functions.Function1

class NicerTypeVariableNamesForErrorMessages implements Function1<String, String> {
	
	
	Map<String, String> seenNames = new HashMap();
	
	var nextSuffix = 1;
	var state = getAlphabet("").iterator;
	
	private static def getAlphabet(String suffix) {
		val char start = 'A';
		val char end = 'Z';
		IntStream.rangeClosed(start, end).mapToObj[(it as char) + suffix]
	}
	
	private def nextName() {
		if(!state.hasNext) {
			state = getAlphabet(String.valueOf(nextSuffix)).iterator;
			nextSuffix++;
		}
		return state.next();
	}
	
	override apply(String varName) {
		if(!seenNames.containsKey(varName)) {
			seenNames.put(varName, nextName());
		}
		return seenNames.get(varName);
	}
	
	def static void main(String[] args) {
		val x = new NicerTypeVariableNamesForErrorMessages();
		val r = new Random();
		val results = newArrayList;
		for(var i = 0; i < 5000; i++) {
			val key = r.nextInt(100);
			val name = x.apply(String.valueOf(key));
			results.add(key -> name);
			print(key);
			print(": ");
			println(name);
		}
		for (a : getAlphabet("").collect(Collectors.toList)) {
			Assert.isTrue(results.exists[it.value == a])
		}
	}
	
}