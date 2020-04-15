/********************************************************************************
 * Copyright (c) 2018 Bosch Connected Devices and Solutions GmbH.
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

package org.eclipse.mita.program.runtime.tests

import com.google.common.collect.Streams
import java.nio.file.Paths
import org.junit.Assert
import org.junit.Test

class RingbufferTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("ringbufferTest", '''
		package my.pkg;
		
		import platforms.x86;
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		
		let a1: ringbuffer<uint8, 2>; 
		let a2: ringbuffer<uint16, 20>;
		let a3: ringbuffer<string<100>, 3>;
		let a4: ringbuffer<array<uint8, 10>, 5>;
		let a5: ringbuffer<array<string<100>, 5>, 3>;
		
		fn report(r: &ringbuffer<uint8, ?>) {
			println(`${(*r).count()} ${(*r).empty()} ${(*r).full()}`);
		} 
		fn report(r: &ringbuffer<uint16, ?>) { 
			println(`${(*r).count()} ${(*r).empty()} ${(*r).full()}`);
		}
		    
		every x86.startup {  
			try {  
				// 0 1 0
				(&a1).report();  
				a1.push(1); 
				// 1 0 0
				(&a1).report();
				a1.push(2);
				// 2 0 1
				(&a1).report();
				// add to full RB
				a1.push(3);
			}
			catch(IndexOutOfBoundsException) {
				// we get here
				println("IOOB");
			}
			try {
				// 0 1 0
				(&a2).report();
				// no such element --> IOOB
				println(`${a2.peek()}`);
			}
			catch(IndexOutOfBoundsException) {
				// we get here
				println("IOOB");
			}
			try {
				// no such element --> IOOB
				println(`${a2.pop()}`);
			}
			catch(IndexOutOfBoundsException) {
				// we get here
				println("IOOB");
			}
			let a2els = a2.capacity() - a2.count();
			for(var i = 0; i < a2els; i++) {
				a2.push(i);
			}
			let a3els = a3.capacity() - a3.count();
			for(var i = 0; i < a3els; i++) {
				a3.push(`${i}`);
			}
			let a4els = a4.capacity() - a4.count();
			for(var i = 0; i < a4els; i++) {
				a4.push([i]);
			}
			let a5els = a5.capacity() - a5.count();
			for(var i = 0; i < a5els; i++) {
				a5.push([`${i}`]);
			}
		} 
		
		/*
		 * Initially:
		 * a1 = [1,2]
		 * a2 = [0,1, ..., 19]
		 * a3 = ["0", "1", "2"]
		 * a4 = [[0], [1], ..., [5]]
		 * a5 = [["0"], ["1"], ["2"]]
		 */
		every 1 second {
			//1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10
			println(`1: ${a1.peek()}`);
			a1.push(a1.pop() + 1);
			
			//0,1,2,3,4,5,6,7,8,...,18
			println(`2: ${a2.peek()}`); 
			a2.push(a2.pop() + 1);
			
			//"0", "1", "2", "01", "11", "21", "011", "111", "211", ..., "211111", "0111111"
			var a3s: string<100> = a3.pop();     
			print("3: ");
			println(a3s);   
			if(a3s.length() < 100) { 
				a3s += "1";
			}
			else { 
				println("a3s full");  
			}
			a3.push(a3s);
			
			// [0], [1], [2], [3], [0, 1], [1, 1], [2, 1], [3, 1], ..., [3, 1, 1, 1] 
			var a4s: array<uint8, 10> = a4.pop(); 
			print("4: ");
			printarray(a4s);
			if(a4s.length() < 10) { 
				a4s += [1 as uint8]; 
			}
			else {
				println("a4s full");  
			}
			a4.push(a4s);
			
			// ["0"], ["1"], ["2"], ["0", "1"], ..., ["0", "1", "1", "1", "1"],  7*"a5s full"
			var a5s: array<string<100>, 5> = a5.pop();
			print("5: ");
			printarray(a5s);
			if(a5s.length() < 5) {
				a5s += ["1"];
			}
			else {
				println("a5s full");
			}
			a5.push(a5s);
			
			if(a1.peek() > 10) {
				exit(0);
			}
		} 
		 
		fn printarray(a: array<uint8, ?>) {
			print("[");
			for(var i = 0; i < a.length(); i++) {
				print(`${a[i]}`);
				if(i < a.length() - 1) {
					print(", ");
				}
			}
			println("]");
		}
		
		fn printarray(a: array<string<?>, ?>) {
			print("[");
			for(var i = 0; i < a.length(); i++) {
				print(`${a[i]}`);
				if(i < a.length() - 1) {
					print(", ");
				}
			}
			println("]");
		}
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val expectations = #[
			"0 1 0",
			"1 0 0",
			"2 0 1",
			"IOOB",
			"0 1 0",
			"IOOB",
			"IOOB",
			"1: 1",
			"2: 0",
			"3: 0",
			"4: [0]",
			"5: [0]",
			"1: 2",
			"2: 1",
			"3: 1",
			"4: [1]",
			"5: [1]",
			"1: 2",
			"2: 2",
			"3: 2",
			"4: [2]",
			"5: [2]",
			"1: 3",
			"2: 3",
			"3: 01",
			"4: [3]",
			"5: [0, 1]",
			"1: 3",
			"2: 4",
			"3: 11",
			"4: [4]",
			"5: [1, 1]",
			"1: 4",
			"2: 5",
			"3: 21",
			"4: [0, 1]",
			"5: [2, 1]",
			"1: 4",
			"2: 6",
			"3: 011",
			"4: [1, 1]",
			"5: [0, 1, 1]",
			"1: 5",
			"2: 7",
			"3: 111",
			"4: [2, 1]",
			"5: [1, 1, 1]",
			"1: 5",
			"2: 8",
			"3: 211",
			"4: [3, 1]",
			"5: [2, 1, 1]",
			"1: 6",
			"2: 9",
			"3: 0111",
			"4: [4, 1]",
			"5: [0, 1, 1, 1]",
			"1: 6",
			"2: 10",
			"3: 1111",
			"4: [0, 1, 1]",
			"5: [1, 1, 1, 1]",
			"1: 7",
			"2: 11",
			"3: 2111",
			"4: [1, 1, 1]",
			"5: [2, 1, 1, 1]",
			"1: 7",
			"2: 12",
			"3: 01111",
			"4: [2, 1, 1]",
			"5: [0, 1, 1, 1, 1]",
			"a5s full",
			"1: 8",
			"2: 13",
			"3: 11111",
			"4: [3, 1, 1]",
			"5: [1, 1, 1, 1, 1]",
			"a5s full",
			"1: 8",
			"2: 14",
			"3: 21111",
			"4: [4, 1, 1]",
			"5: [2, 1, 1, 1, 1]",
			"a5s full",
			"1: 9",
			"2: 15",
			"3: 011111",
			"4: [0, 1, 1, 1]",
			"5: [0, 1, 1, 1, 1]",
			"a5s full",
			"1: 9",
			"2: 16",
			"3: 111111",
			"4: [1, 1, 1, 1]",
			"5: [1, 1, 1, 1, 1]",
			"a5s full",
			"1: 10",
			"2: 17",
			"3: 211111",
			"4: [2, 1, 1, 1]",
			"5: [2, 1, 1, 1, 1]",
			"a5s full",
			"1: 10",
			"2: 18",
			"3: 0111111",
			"4: [3, 1, 1, 1]",
			"5: [0, 1, 1, 1, 1]",
			"a5s full"
		];
		Streams.zip(lines, expectations.stream, [s1, s2|
			Assert.assertEquals(s1.trim, s2.trim);
			return null;
		])
		return;
	}
}