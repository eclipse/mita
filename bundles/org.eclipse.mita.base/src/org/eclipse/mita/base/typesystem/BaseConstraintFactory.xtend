package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.scoping.IScopeProvider

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected ConstraintSystemProvider constraintSystemProvider;
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	public override ConstraintSystem create(SymbolTable symbols, EObject context) {
		val result = constraintSystemProvider.get(symbols);
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''computeConstraints is not implemented for «context.eClass.name»''');
		context.eContents.forEach[ system.computeConstraints(it) ]
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PrimitiveType type) {
		new TypeVariable(type) => [ typeVar |
			system.addConstraint(new Equality(typeVar, new AtomicType(type)));
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructureType structType) {
		new TypeVariable(structType) => [ typeVar |
			val types = structType.accessorsTypes.map[ 
				system.computeConstraints(it) as AbstractType;
			];
			system.addConstraint(new Equality(typeVar, new ProdType(structType, types)));
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		new TypeVariable(sumType) => [typeVar |
			val types = sumType.alternatives.map[ 
				system.computeConstraints(it) as AbstractType;
			];
			system.addConstraint(new Equality(typeVar, new SumType(sumType, types)));
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SumAlternative sumAlt) {
		new TypeVariable(sumAlt) => [typeVar |
			val types = sumAlt.accessorsTypes.map[ 
				system.computeConstraints(it) as AbstractType;
			];
			system.addConstraint(new Equality(typeVar, new ProdType(sumAlt, types)));
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
		new TypeVariable(typeSpecifier) => [ typeVar |
			val scope = scopeProvider.getScope(typeSpecifier, TypesPackage.eINSTANCE.typeSpecifier_Type);
			val typeText = NodeModelUtils.findNodesForFeature(typeSpecifier, TypesPackage.eINSTANCE.typeSpecifier_Type).head.text;
			val typeQN = scope.getSingleElement(QualifiedName.create(typeText.split('.'))).qualifiedName;
			//val referencedTypeVar = system.typeTable.getContent.get(typeQN);
			//system.addConstraint(new Equality(typeVar, referencedTypeVar));
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
}