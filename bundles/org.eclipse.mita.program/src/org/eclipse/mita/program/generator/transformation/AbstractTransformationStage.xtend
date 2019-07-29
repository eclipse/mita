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

package org.eclipse.mita.program.generator.transformation

import com.google.inject.Inject
import java.util.LinkedList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AbstractStatement
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.scoping.IScopeProvider

abstract class AbstractTransformationStage {
	
	@Inject 
	protected extension ProgramCopier copier
	
	@Inject
	protected ITypeSystem typeSystem
	
	@Inject
	protected IScopeProvider scopeProvider
	
	@Inject
	protected extension GeneratorUtils
	
	protected ITransformationPipelineInfoProvider pipelineInfoProvider;
	
	final List<(EObject)=>void> postTransformations = new LinkedList;
	
	public static final int ORDER_VERY_EARLY = 100;
	public static final int ORDER_EARLY = 300;
	public static final int ORDER_INBETWEEN = 500;
	public static final int ORDER_LATE = 700;
	public static final int ORDER_VERY_LATE = 900;
	public static final int ORDER_CUSTOM_STUFF = 1100;
	
	static def before(int x) {
		return x - 10;
	}
	static def afterwards(int x) {
		return x + 10;
	}
	
	def transform(ITransformationPipelineInfoProvider pipeline, Program program) {
		pipelineInfoProvider = pipeline;
		
		program.doTransform();
		doPostTransformations(program);
		
		return program;
	}
	
	protected def doPostTransformations(Program program) {
		postTransformations.forEach[x | x.apply(program) ]
	}
	
	def getOrder() {
		return ORDER_CUSTOM_STUFF;
	}
	
	protected def void addPostTransformation((EObject) => void func) {
		postTransformations.add(func);
	}
	
	protected dispatch def void doTransform(EObject obj) {
		obj.transformChildren();
	}
	
	protected def void transformChildren(EObject obj) {
		for(child : obj.eContents) {
			child.doTransform();
		}
	}
	
	protected def void insertNextToParentBlock(EObject context, boolean insertBefore, AbstractStatement... content) {
		// let's find the parent program block first
		var block = null as ProgramBlock;
		var current = context;
		while(block === null && current !== null) {
			val parent = current.eContainer;
			if(parent instanceof ProgramBlock) {
				block = parent;
			} else {
				current = parent;
			}
		}
		
		// if we have found a parent block and the path to that block, insert the content
		if(block !== null && current !== null) {
			val insertionPosition = block.content.indexOf(current);
			if(insertBefore) {
				block.content.addAll(insertionPosition, content);
			} else {
				block.content.addAll(insertionPosition + 1, content);
			}
		} else {
			// TODO: We do not have logging here. That's bad!
		}
	}
	
	protected def findPositionOfAncestor(ProgramBlock block, EObject ref) {
		// let's find our element in the block
		var refAncestor = null as EObject;
		for(var current = ref; current !== null && refAncestor === null; current = current?.eContainer) {
			if(current?.eContainer == block) {
				refAncestor = current;
			}
		}
		
		// if we haven't found a path here we're done
		if(refAncestor === null) {
			return -1;
		} else {
			block.content.indexOf(refAncestor);
		}
	}
	
	/**
	 * Replaces an object within its container.
	 */
	static public def void replaceWith(EObject target, EObject replacement) {
		val container = target.eContainer;
		if(container === null) return;
		
		ProgramCopier.linkOrigin(replacement, target);
		if(target.eContainingFeature.isMany) {
			val containerList = (container.eGet(target.eContainmentFeature) as List<EObject>);
			val index = containerList.indexOf(target);
			if(index < 0) return;
			
			containerList.set(index, replacement);
		} else {
			container.eSet(target.eContainingFeature, replacement);
		}
	}
	
}