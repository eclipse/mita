package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.regex.Pattern
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
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.NativeType
import org.eclipse.xtext.naming.QualifiedName

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
		val intPatternMatcher = Pattern.compile("(int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			return system.associate(type, new IntegerType(type, size, signed));
		} else {
			return system.associate(type, new AtomicType(type, type.name));
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		return system.associate(structType, new ProdType(structType, types));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val types = sumType.alternatives.map[ system.computeConstraints(it) as AbstractType ];
		return system.associate(sumType, new SumType(sumType, types));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SumAlternative sumAlt) {
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		return system.associate(sumAlt, new ProdType(sumAlt, types));
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
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NativeType enumerator) {
		return system.associate(enumerator, new AtomicType(enumerator, enumerator.name));
	}
	
//	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
//		
//	}
//	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
	protected def associate(ConstraintSystem system, EObject origin, AbstractType t) {
		val typeVar = new TypeVariable(origin);
		system.addConstraint(new Equality(typeVar, t));
		return typeVar;
	}
	
}