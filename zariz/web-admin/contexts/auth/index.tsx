import { createContext, useEffect, useReducer } from "react";
import { ContextType, DataType, ProviderType } from "./types";
import { reducer } from "./reducer";
import { authClient } from "../../libs/authClient";

export { useAuthContext } from './hook';

const initialState: DataType = {
    token: '',
    user: null
}

export const AppContext = createContext<ContextType>({
    state: initialState,
    dispatch: () => {}
});

export const Provider = ({ children }: ProviderType) => {
    const [state, dispatch] = useReducer(reducer, initialState);
    const value = {state, dispatch};

    // bootstrap from refresh cookie if present
    useEffect(() => {
        let unsub = authClient.subscribe((token) => {
            dispatch({ type: 0, payload: { token: token || '' } }) // Actions.SET_TOKEN === 0
        })
        authClient.refresh().catch(() => {/* no session */})
        return () => { unsub && unsub() }
    }, [])

    return (
        <AppContext.Provider value={value}>
            {children}
        </AppContext.Provider>
    )
}
