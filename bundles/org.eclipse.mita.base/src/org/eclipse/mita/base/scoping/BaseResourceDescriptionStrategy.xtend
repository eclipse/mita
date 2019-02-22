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

package org.eclipse.mita.base.scoping

import com.google.common.collect.Maps
import com.google.inject.Inject
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import org.eclipse.mita.base.types.Exportable
import org.eclipse.mita.base.types.GeneratedObject
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.solver.CoerciveSubtypeSolver
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.impl.DefaultResourceDescriptionStrategy
import org.eclipse.xtext.util.IAcceptor

import static extension org.eclipse.mita.base.util.BaseUtils.force;

class BaseResourceDescriptionStrategy extends DefaultResourceDescriptionStrategy {
	public static final String TYPE = "TYPE"
	public static final String EXPORTED = "EXPORTED"
	public static final String CONSTRAINTS = "CONSTRAINTS";
	
	@Inject 
	protected TypeQualifiedNameProvider typeQualifiedNameProvider;
	
	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject 
	protected SerializationAdapter serializationAdapter;
	
	@Inject
	protected CoerciveSubtypeSolver coerciveSubtypeSolver;
	
	dispatch def boolean isExported(Exportable obj) {
		return obj.exported;
	}
	dispatch def boolean isExported(SumAlternative obj) {
		return obj.eContainer.isExported;
	}
	dispatch def boolean isExported(GeneratedObject obj) {
		return obj.eContainer.isExported;
	}
	dispatch def boolean isExported(EObject obj) {
		return true;
	}
	
	def void defineUserData(EObject eObject, Map<String, String> userData) {
		if (eObject instanceof TypedElement) {
			userData.put(TYPE, getTypeSpecifierType(((eObject as TypedElement)).getTypeSpecifier()))
		}
		
		userData.put(EXPORTED, Boolean.toString(eObject.isExported));
		
		if (eObject.eContainer() === null) {
			// constraint generation assumes a valid model. In an invalid model things might be null we don't check
			// for example if a user writes &&x the parser constructs:
			// BinaryExpression(DOUBLE_AND, null, x)
			// and we don't handle that. 
			val resource = eObject.eResource;
			if(resource instanceof ResourceImpl) {
				val errors = resource.errors;
				if(!errors.nullOrEmpty) {
					return;
				}
			}
			eObject.eAllContents
				.filter(GeneratedObject)
				.forEach[
					it.generateMembers()
				]
			
			// we're at the top level element - let's compute constraints and put that in a new EObjectDescription
			constraintFactory.getTypeRegistry().setIsLinking(true);
			val constraints = constraintFactory.create(eObject);
			val packageName = (eObject as PackageAssociation).name
			
//			val csCopy = new ConstraintSystem(constraints);
//			val simplification = coerciveSubtypeSolver.simplify(csCopy, Substitution.EMPTY, eObject);
//			val substitution = simplification.substitution;
//			val simplifiedConstraints = substitution.apply(constraints);
//			
//			simplifiedConstraints.nonAtomicConstraints = simplifiedConstraints.nonAtomicConstraints.filter[
//				if(it instanceof EqualityConstraint) {
//					return it.left == it.right;
//				}
//				return false;
//			].force;
//			
//			substitution.substitutions.forEach[t1, t2|
//				simplifiedConstraints.nonAtomicConstraints.add(new EqualityConstraint(t1, t2, new ValidationIssue("Definition", t1.origin ?: t2.origin)))
//			]
			constraints.typeTable.entrySet.force.forEach[
				if(!it.value.origin.isExported) {
					constraints.typeTable.remove(it.key);
				}
			]
//			constraints.typeClasses.entrySet.force.forEach[tc |
//				tc.value.instances.entrySet.force.forEach[
//					if(!it.value.isExported) {
//						tc.value.instances.remove(it.key);
//					}
//				]
//			]
			
			val String json = serializationAdapter.toJSON(constraints);
			userData.put(CONSTRAINTS, json);
//			val String json = serializationAdapter.toJSON(constraints);
//			val jsonCompressed = GZipper.compress(json);
//			userData.put(CONSTRAINTS, jsonCompressed);
//			val lenRaw = json.length;
//			val lenCompressed = jsonCompressed.length;
			if(eObject.eResource.URI.lastSegment == "application.mita") {
				print("");	
			}
		}
	}

	static def String getTypeSpecifierType(TypeSpecifier specifier) {
		if(specifier instanceof PresentTypeSpecifier){
			if(specifier.optional){
				return MitaTypeSystem.OPTIONAL_TYPE
			} else if (!specifier.referenceModifiers.isEmpty){
				return MitaTypeSystem.REFERENCE_TYPE
			}
		}
		var List<INode> typeNode = NodeModelUtils.findNodesForFeature(specifier,
			TypesPackage.Literals.PRESENT_TYPE_SPECIFIER__TYPE)
		if (typeNode.size() === 1) {
			return typeNode.get(0).getText().trim()
		} else {
			return "void"
		}
	}

	override boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor) {
		return createEObjectDescriptions(eObject, acceptor, qualifiedNameProvider);
	}

	def boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor, IQualifiedNameProvider nameProvider) {
		val Map<String, String> userData = Maps.newHashMap()		
		if(getQualifiedNameProvider() === null) return false
		if(!shouldCreateDescription(eObject)) {
			return false;
		}
		val QualifiedName qualifiedName = nameProvider.getFullyQualifiedName(eObject)
		if (qualifiedName === null) {
			nameProvider.getFullyQualifiedName(eObject)
			return false;
		}
		try {
			defineUserData(eObject, userData)
			acceptor.accept(EObjectDescription.create(qualifiedName, eObject, userData))
			val secondQN = typeQualifiedNameProvider.getFullyQualifiedName(eObject);
			if(secondQN !== null && secondQN != qualifiedName) {
				acceptor.accept(EObjectDescription.create(secondQN, eObject, userData))
			}
		} catch (Exception exc) {
			exc.printStackTrace()
		}
		return true
	}

	def protected boolean shouldCreateDescription(EObject object) {
		return !(object instanceof StructuralParameter)
	}
}
