package org.eclipse.mita.base.typesystem.serialization

import java.util.ArrayList
import java.util.List
import java.util.Map
import org.eclipse.mita.base.typesystem.types.Signedness

class SerializedObject {
    public String _type;
}

class SerializedConstraintSystem extends SerializedObject {
    new() {
        _type = "SerializedConstraintSystem";
    }

	public List<SerializedAbstractTypeConstraint> constraints = new ArrayList;
	public Map<String, SerializedTypeClass> typeClasses;
}

class SerializedTypeClass extends SerializedObject {
    new() {
        _type = "SerializedTypeClass";
    }

	public Map<SerializedAbstractType, Object> instances;
}

abstract class SerializedAbstractType extends SerializedObject {
    new() {
        _type = "SerializedAbstractType";
    }

	public String origin;
	public String name;
}

abstract class SerializedAbstractBaseType extends SerializedAbstractType {
    new() {
        _type = "SerializedAbstractBaseType";
    }

}

class SerializedAtomicType extends SerializedAbstractBaseType {
    new() {
        _type = "SerializedAtomicType";
    }

}

class SerializedBaseKind extends SerializedAbstractBaseType {
    new() {
        _type = "SerializedBaseKind";
    }

	public SerializedAbstractType kindOf;
}

class SerializedBottomType extends SerializedAbstractBaseType {
    new() {
        _type = "SerializedBottomType";
    }

	public String message;
}

class SerializedNumericType extends SerializedAbstractBaseType {
    new() {
        _type = "SerializedNumericType";
    }

	public int widthInBytes;
}

class SerializedFloatingType extends SerializedNumericType {
    new() {
        _type = "SerializedFloatingType";
    }

}

class SerializedIntegerType extends SerializedNumericType {
    new() {
        _type = "SerializedIntegerType";
    }

	public Signedness signedness;
}

class SerializedTypeConstructorType extends SerializedAbstractType {
    new() {
        _type = "SerializedTypeConstructorType";
    }

	public List<SerializedAbstractType> typeArguments;
	public List<SerializedAbstractType> superTypes;
}

class SerializedFunctionType extends SerializedTypeConstructorType {
    new() {
        _type = "SerializedFunctionType";
    }

	public SerializedAbstractType from;
	public SerializedAbstractType to;
}

class SerializedProductType extends SerializedTypeConstructorType {
    new() {
        _type = "SerializedProductType";
    }

}

class SerializedCoSumType extends SerializedProductType {
    new() {
        _type = "SerializedCoSumType";
    }

}

class SerializedSumType extends SerializedTypeConstructorType {
    new() {
        _type = "SerializedSumType";
    }

}

class SerializedTypeScheme extends SerializedAbstractType {
    new() {
        _type = "SerializedTypeScheme";
    }

	public List<SerializedTypeVariable> vars;
	public SerializedAbstractType on;
}

class SerializedTypeVariable extends SerializedAbstractType {
    new() {
        _type = "SerializedTypeVariable";
    }
}

class SerializedTypeVariableProxy extends SerializedTypeVariable {
    new() {
        _type = "SerializedTypeVariableProxy";
    }
    
	public SerializedEReference reference;
	public String targetQID;
}

class SerializedAbstractTypeConstraint extends SerializedObject {
    new() {
        _type = "SerializedAbstractTypeConstraint";
    }

}

class SerializedEqualityConstraint extends SerializedAbstractTypeConstraint {
    new() {
        _type = "SerializedEqualityConstraint";
    }

	public String source;
	public SerializedAbstractType left;
	public SerializedAbstractType right;
}

class SerializedExplicitInstanceConstraint extends SerializedAbstractTypeConstraint {
    new() {
        _type = "SerializedExplicitInstanceConstraint";
    }

	public SerializedAbstractType instance;
	public SerializedAbstractType typeScheme;
}

class SerializedSubtypeConstraint extends SerializedAbstractTypeConstraint {
    new() {
        _type = "SerializedSubtypeConstraint";
    }

	public SerializedAbstractType subType;
	public SerializedAbstractType superType;
}

class SerializedEReference extends SerializedObject {
	new() {
		_type = "SerializedEReference";
	}
	public String javaClass;
	public String javaField;
	public String javaMethod;
	public String ePackageName;
	public String eClassName;
	public String eReferenceName;
}
 
class SerializedFunctionTypeClassConstraint extends SerializedAbstractTypeConstraint {
    new() {
        _type = "SerializedTypeclassConstraint";
    }

	public SerializedAbstractType type;
	public String functionCall;
	public SerializedObject functionReference;
	public SerializedTypeVariable returnTypeTV;
	public String instanceOfQN;
}

