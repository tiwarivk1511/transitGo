class AuthorizedRailwayProvider:

    async def get_train_status(
            self,
            train_number: str,
            journey_date: str,
    ):

        raise NotImplementedError(
            "Configure only with an "
            "authorized railway data provider."
        )