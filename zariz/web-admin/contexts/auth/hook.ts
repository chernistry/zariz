import { useContext } from "react"
import { AppContext } from "."
import { User } from "../../types/User";
import { Actions, AuthActions } from "./types";
import { authClient } from "../../libs/authClient";

export const useAuthContext = () => {
    const { state, dispatch } = useContext(AppContext);
    const actions: AuthActions = {
        setToken: (token: string) => {
            authClient._set(token || null);
            dispatch({ type: Actions.SET_TOKEN, payload: { token } });
        },
        setUser: (user: User | null) => {
            dispatch({ type: Actions.SET_USER, payload: { user } });
        },
        login: async (identifier: string, password: string) => {
            const { token } = await authClient.login(identifier, password)
            dispatch({ type: Actions.SET_TOKEN, payload: { token } });
        },
        logout: async () => {
            await authClient.logout();
            dispatch({ type: Actions.SET_TOKEN, payload: { token: '' } });
            dispatch({ type: Actions.SET_USER, payload: { user: null } });
        },
    }
    return { ...state, ...actions }
}
