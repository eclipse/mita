package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeScheme
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

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Type type) {
		system.associate(system.translateTypeDeclaration(type), type);
	}

	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		val intPatternMatcher = Pattern.compile("(int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, signed);
		} else {
			new AtomicType(type, type.name);
		}
	}

	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		return new ProdType(structType, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val types = sumType.alternatives.map[ system.computeConstraints(it) as AbstractType ];
		return new SumType(sumType, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		return new ProdType(sumAlt, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val atomicType = new AtomicType(genType);
		if(typeParameters.empty) {
			return atomicType;
		}
		else {
			val typeArgs = typeParameters.map[ system.computeConstraints(it) ];
			return new TypeScheme(genType, typeArgs, atomicType);
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
		new TypeVariable(typeSpecifier) => [ typeVar |
			
			val typeArguments = typeSpecifier.typeArguments;
			if(typeArguments.empty) {
				system.addConstraint(new Equality(typeVar, system.computeConstraints(typeSpecifier.type)))
			}
			else {
				val vars_typeScheme = system.translateTypeDeclaration(typeSpecifier.type).instantiate();
				system.addConstraint(new Equality(typeVar, vars_typeScheme.value));
				
				val vars = vars_typeScheme.key;
				for(var i = 0; i < Integer.min(typeArguments.size, vars.size); i++) {
					system.addConstraint(new Equality(vars.get(i), system.computeConstraints(typeArguments.get(i))));
				}
			}
		]
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NativeType enumerator) {
		return system.associate(new AtomicType(enumerator, enumerator.name));
	}
	
//	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
//		
//	}
//	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
	protected def associate(ConstraintSystem system, AbstractType t) {
		return associate(system, t, t.origin);
	}
	
	protected def associate(ConstraintSystem system, AbstractType t, EObject typeVarOrigin) {
		val typeVar = new TypeVariable(typeVarOrigin);
		system.addConstraint(new Equality(typeVar, t));
		return typeVar;
	}
	
}